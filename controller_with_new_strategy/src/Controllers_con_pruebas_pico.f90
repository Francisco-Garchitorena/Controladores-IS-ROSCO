! Copyright 2019 NREL

! Licensed under the Apache License, Version 2.0 (the "License"); you may not use
! this file except in compliance with the License. You may obtain a copy of the
! License at http://www.apache.org/licenses/LICENSE-2.0

! Unless required by applicable law or agreed to in writing, software distributed
! under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
! CONDITIONS OF ANY KIND, either express or implied. See the License for the
! specific language governing permissions and limitations under the License.
! -------------------------------------------------------------------------------------------

! This module contains the primary controller routines

MODULE Controllers

    USE, INTRINSIC :: ISO_C_Binding
    USE Functions
    USE Filters
    USE ControllerBlocks

    IMPLICIT NONE

CONTAINS
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE PitchControl(avrSWAP, CntrPar, LocalVar, objInst, DebugVar, ErrVar)
    ! Blade pitch controller, generally maximizes rotor speed below rated (region 2) and regulates rotor speed above rated (region 3)
    !       PC_State = 0, fix blade pitch to fine pitch angle (PC_FinePit)
    !       PC_State = 1, is gain scheduled PI controller
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances, DebugVariables, ErrorVariables

        ! Inputs
        REAL(ReKi),              INTENT(INOUT)       :: avrSWAP(*)   ! The swap array, used to pass data to, and receive data from the DLL controller.
        TYPE(ControlParameters),    INTENT(INOUT)       :: CntrPar
        TYPE(LocalVariables),       INTENT(INOUT)       :: LocalVar
        TYPE(ObjectInstances),      INTENT(INOUT)       :: objInst
        TYPE(DebugVariables),       INTENT(INOUT)       :: DebugVar
        TYPE(ErrorVariables),       INTENT(INOUT)       :: ErrVar

        ! Allocate Variables:
        INTEGER(IntKi)                                  :: K            ! Index used for looping through blades.

        CHARACTER(*),               PARAMETER           :: RoutineName = 'PitchControl'

        ! ------- Blade Pitch Controller --------
        ! Load PC State
        IF (LocalVar%PC_State == 1) THEN ! PI BldPitch control
            LocalVar%PC_MaxPit = CntrPar%PC_MaxPit
        ELSE ! debug mode, fix at fine pitch
            LocalVar%PC_MaxPit = CntrPar%PC_FinePit
        END IF

        ! Compute (interpolate) the gains based on previously commanded blade pitch angles and lookup table:
        LocalVar%PC_KP = interp1d(CntrPar%PC_GS_angles, CntrPar%PC_GS_KP, LocalVar%PC_PitComTF, ErrVar) ! Proportional gain
        LocalVar%PC_KI = interp1d(CntrPar%PC_GS_angles, CntrPar%PC_GS_KI, LocalVar%PC_PitComTF, ErrVar) ! Integral gain
        LocalVar%PC_KD = interp1d(CntrPar%PC_GS_angles, CntrPar%PC_GS_KD, LocalVar%PC_PitComTF, ErrVar) ! Derivative gain
        LocalVar%PC_TF = interp1d(CntrPar%PC_GS_angles, CntrPar%PC_GS_TF, LocalVar%PC_PitComTF, ErrVar) ! TF gains (derivative filter) !NJA - need to clarify
        !PRINT *, 'Speed error: ', LocalVar%PC_SpdErr

        ! Compute the collective pitch command associated with the proportional and integral gains:
        LocalVar%PC_PitComT = PIController(LocalVar%PC_SpdErr, LocalVar%PC_KP, LocalVar%PC_KI, LocalVar%PC_MinPit, LocalVar%PC_MaxPit, LocalVar%DT, LocalVar%BlPitch(1), LocalVar%piP, LocalVar%restart, objInst%instPI)
        DebugVar%PC_PICommand = LocalVar%PC_PitComT
        !PRINT *, 'pitch command: ', LocalVar%Time, LocalVar%PC_PitComTF, LocalVar%PC_PitComT, LocalVar%PC_KP, LocalVar%PC_KI, LocalVar%PC_SpdErr
        ! Find individual pitch control contribution
        IF ((CntrPar%IPC_ControlMode >= 1) .OR. (CntrPar%Y_ControlMode == 2)) THEN
            CALL IPC(CntrPar, LocalVar, objInst, DebugVar, ErrVar)
        ELSE
            LocalVar%IPC_PitComF = 0.0 ! THIS IS AN ARRAY!!
        END IF

        ! Include tower fore-aft tower vibration damping control
        IF (CntrPar%TD_Mode > 0) THEN
            CALL ForeAftDamping(CntrPar, LocalVar, objInst)
        ELSE
            LocalVar%FA_PitCom = 0.0 ! THIS IS AN ARRAY!!
        ENDIF

        ! Pitch Saturation
        IF (CntrPar%PS_Mode > 0) THEN
            LocalVar%PC_MinPit = PitchSaturation(LocalVar,CntrPar,objInst,DebugVar, ErrVar)
            LocalVar%PC_MinPit = max(LocalVar%PC_MinPit, CntrPar%PC_FinePit)
        ELSE
            LocalVar%PC_MinPit = CntrPar%PC_FinePit
        ENDIF
        DebugVar%PC_MinPit = LocalVar%PC_MinPit

        ! FloatingFeedback
        IF (CntrPar%Fl_Mode > 0) THEN
            LocalVar%Fl_PitCom = FloatingFeedback(LocalVar, CntrPar, objInst, ErrVar)
            DebugVar%FL_PitCom = LocalVar%Fl_PitCom
            LocalVar%PC_PitComT = LocalVar%PC_PitComT + LocalVar%Fl_PitCom
        ENDIF

        ! Shutdown
        IF (CntrPar%SD_Mode == 1) THEN
            LocalVar%PC_PitComT = Shutdown(LocalVar, CntrPar, objInst)
        ENDIF

        ! Saturate collective pitch commands:
        LocalVar%PC_PitComT = saturate(LocalVar%PC_PitComT, LocalVar%PC_MinPit, CntrPar%PC_MaxPit)                    ! Saturate the overall command using the pitch angle limits
        LocalVar%PC_PitComT = ratelimit(LocalVar%PC_PitComT, CntrPar%PC_MinRat, CntrPar%PC_MaxRat, LocalVar%DT, LocalVar%restart, LocalVar%rlP,objInst%instRL,LocalVar%BlPitchCMeas) ! Saturate the overall command of blade K using the pitch rate limit
        LocalVar%PC_PitComT_Last = LocalVar%PC_PitComT

        ! Combine and saturate all individual pitch commands in software
        DO K = 1,LocalVar%NumBl ! Loop through all blades, add IPC contribution and limit pitch rate
            LocalVar%PitCom(K) = LocalVar%PC_PitComT + LocalVar%FA_PitCom(K)
            LocalVar%PitCom(K) = saturate(LocalVar%PitCom(K), LocalVar%PC_MinPit, CntrPar%PC_MaxPit)                    ! Saturate the command using the pitch saturation limits
            LocalVar%PitCom(K) = LocalVar%PitCom(K) + LocalVar%IPC_PitComF(K)                                          ! Add IPC

            ! Hard IPC saturation by peak shaving limit
            IF (CntrPar%IPC_SatMode == 1) THEN
                LocalVar%PitCom(K) = saturate(LocalVar%PitCom(K), LocalVar%PC_MinPit, CntrPar%PC_MaxPit)
            END IF

            ! Add ZeroMQ pitch commands
            LocalVar%PitCom(K) = LocalVar%PitCom(K) + LocalVar%ZMQ_PitOffset(K)

            ! Rate limit
            LocalVar%PitCom(K) = ratelimit(LocalVar%PitCom(K), CntrPar%PC_MinRat, CntrPar%PC_MaxRat, LocalVar%DT, LocalVar%restart, LocalVar%rlP,objInst%instRL,LocalVar%BlPitch(K)) ! Saturate the overall command of blade K using the pitch rate limit
        END DO

        ! Open Loop control, use if
        !   Open loop mode active         Using OL blade pitch control
        IF (CntrPar%OL_Mode > 0) THEN
            IF (LocalVar%Time >= CntrPar%OL_Breakpoints(1)) THEN    ! Time > first open loop breakpoint
                IF (CntrPar%Ind_BldPitch(1) > 0) THEN
                    LocalVar%PitCom(1) = interp1d(CntrPar%OL_Breakpoints,CntrPar%OL_BldPitch1,LocalVar%Time, ErrVar)
                ENDIF

                IF (CntrPar%Ind_BldPitch(2) > 0) THEN
                    LocalVar%PitCom(2) = interp1d(CntrPar%OL_Breakpoints,CntrPar%OL_BldPitch2,LocalVar%Time, ErrVar)
                ENDIF

                IF (CntrPar%Ind_BldPitch(3) > 0) THEN
                    LocalVar%PitCom(3) = interp1d(CntrPar%OL_Breakpoints,CntrPar%OL_BldPitch3,LocalVar%Time, ErrVar)
                ENDIF
            ENDIF
        ENDIF

        ! Active wake control
        IF (CntrPar%AWC_Mode > 0) THEN
            CALL ActiveWakeControl(CntrPar, LocalVar, DebugVar)
        ENDIF

        ! Place pitch actuator here, so it can be used with or without open-loop
        DO K = 1,LocalVar%NumBl ! Loop through all blades, add IPC contribution and limit pitch rate
            IF (CntrPar%PA_Mode > 0) THEN
                IF (CntrPar%PA_Mode == 1) THEN
                    LocalVar%PitComAct(K) = LPFilter(LocalVar%PitCom(K), LocalVar%DT, CntrPar%PA_CornerFreq, LocalVar%FP, LocalVar%iStatus, LocalVar%restart, objInst%instLPF)
                ELSE IF (CntrPar%PA_Mode == 2) THEN
                    LocalVar%PitComAct(K) = SecLPFilter(LocalVar%PitCom(K),LocalVar%DT,CntrPar%PA_CornerFreq,CntrPar%PA_Damping,LocalVar%FP,LocalVar%iStatus,LocalVar%restart,objInst%instSecLPF)
                END IF
            ELSE
                LocalVar%PitComAct(K) = LocalVar%PitCom(K)
            ENDIF
        END DO

        ! Hardware saturation: using CntrPar%PC_MinPit
        DO K = 1,LocalVar%NumBl ! Loop through all blades, add IPC contribution and limit pitch rate
            ! Saturate the pitch command using the overall (hardware) limit
            LocalVar%PitComAct(K) = saturate(LocalVar%PitComAct(K), CntrPar%PC_MinPit, CntrPar%PC_MaxPit)
            ! Saturate the overall command of blade K using the pitch rate limit
            LocalVar%PitComAct(K) = ratelimit(LocalVar%PitComAct(K), CntrPar%PC_MinRat, CntrPar%PC_MaxRat, LocalVar%DT, LocalVar%restart, LocalVar%rlP,objInst%instRL,LocalVar%BlPitch(K)) ! Saturate the overall command of blade K using the pitch rate limit
        END DO

        ! Add pitch actuator fault for blade K
        IF (CntrPar%PF_Mode == 1) THEN
            DO K = 1, LocalVar%NumBl
                ! This assumes that the pitch actuator fault overides the Hardware saturation
                LocalVar%PitComAct(K) = LocalVar%PitComAct(K) + CntrPar%PF_Offsets(K)
            END DO
        END IF

        ! Command the pitch demanded from the last
        ! call to the controller (See Appendix A of Bladed User's Guide):
        avrSWAP(42) = LocalVar%PitComAct(1)   ! Use the command angles of all blades if using individual pitch
        avrSWAP(43) = LocalVar%PitComAct(2)   ! "
        avrSWAP(44) = LocalVar%PitComAct(3)   ! "
        avrSWAP(45) = LocalVar%PitComAct(1)   ! Use the command angle of blade 1 if using collective pitch

        ! Add RoutineName to error message
        IF (ErrVar%aviFAIL < 0) THEN
            ErrVar%ErrMsg = RoutineName//':'//TRIM(ErrVar%ErrMsg)
        ENDIF

    END SUBROUTINE PitchControl
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE VariableSpeedControl(avrSWAP, CntrPar, LocalVar, DebugVar, objInst, ErrVar)
    ! Generator torque controller
    !       VS_State = 0, Error state, for debugging purposes, GenTq = VS_RtTq
    !       VS_State = 1, Region 1(.5) operation, torque control to keep the rotor at cut-in speed towards the Cp-max operational curve
    !       VS_State = 2, Region 2 operation, maximum rotor power efficiency (Cp-max) tracking using K*omega^2 law, fixed fine-pitch angle in BldPitch controller
    !       VS_State = 3, Region 2.5, transition between below and above-rated operating conditions (near-rated region) using PI torque control
    !       VS_State = 4, above-rated operation using pitch control (constant torque mode)
    !       VS_State = 5, above-rated operation using pitch and torque control (constant power mode)
    !       VS_State = 6, Tip-Speed-Ratio tracking PI controller
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, DebugVariables, ObjectInstances, ErrorVariables
        ! Inputs
        REAL(ReKi),                 INTENT(INOUT)       :: avrSWAP(*)    ! The swap array, used to pass data to, and receive data from, the DLL controller.
        TYPE(ControlParameters),    INTENT(INOUT)       :: CntrPar
        TYPE(LocalVariables),       INTENT(INOUT)       :: LocalVar
        TYPE(DebugVariables),       INTENT(INOUT)       :: DebugVar  !Agrega FG 03/07/25
        TYPE(ObjectInstances),      INTENT(INOUT)       :: objInst
        TYPE(ErrorVariables),       INTENT(INOUT)       :: ErrVar

        CHARACTER(*),               PARAMETER           :: RoutineName = 'VariableSpeedControl'

        ! Allocate Variables

        ! -------- Variable-Speed Torque Controller --------
        ! Define max torque
        IF (LocalVar%VS_State == 4) THEN
           LocalVar%VS_MaxTq = CntrPar%VS_RtTq
        ELSE
            ! VS_MaxTq = CntrPar%VS_MaxTq           ! NJA: May want to boost max torque
            LocalVar%VS_MaxTq = CntrPar%VS_MaxTq ! CFG 01/09: CntrPar%VS_RtTq
        ENDIF

        ! Optimal Tip-Speed-Ratio tracking controller
        IF ((CntrPar%VS_ControlMode == 2) .OR. (CntrPar%VS_ControlMode == 3)) THEN
            ! Constant Power, update VS_MaxTq
            IF (CntrPar%VS_ConstPower == 1) THEN
                LocalVar%VS_MaxTq = min((CntrPar%VS_RtPwr/(CntrPar%VS_GenEff/100.0))/LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
            END IF

            ! PI controller
            ! Agrega FG 12/11:
            ! IF ((LocalVar%IS_status == 1) .OR. (LocalVar%IS_status == 1.5) .OR. (LocalVar%IS_status == 2) ) THEN
            !     LocalVar%VS_SpdErr = 0
            ! ENDIF
            ! IF (LocalVar%IS_status == 2 .OR. (LocalVar%IS_status == 3) ) THEN !Prueba 14/11:  saturar el error----no funciona, queda en 1 durante todo el satatus 2 y 3 el torque baja. 
            !   !  PRINT *, 'VSGenTq: ', LocalVar%GenTq , 'VS_LastGenTrq:', LocalVar%VS_LastGenTrq
            !   LocalVar%VS_SpdErr = MAX( -1_ReKi, MIN(LocalVar%VS_SpdErr, 1.4_ReKi) )
            ! ENDIF
            LocalVar%GenTq = PIController( &
                                        LocalVar%VS_SpdErr, &
                                        CntrPar%VS_KP(1), &
                                        CntrPar%VS_KI(1), &
                                        CntrPar%VS_MinTq, LocalVar%VS_MaxTq, &
                                        LocalVar%DT, LocalVar%VS_LastGenTrq, LocalVar%piP, LocalVar%restart, objInst%instPI)
           
            LocalVar%GenTq = saturate(LocalVar%GenTq, CntrPar%VS_MinTq, LocalVar%VS_MaxTq)
            DebugVar%VS_SpdErr = LocalVar%VS_SpdErr
        ! K*Omega^2 control law with PI torque control in transition regions
        ELSEIF (CntrPar%VS_ControlMode == 1) THEN
            ! Update PI loops for region 1.5 and 2.5 PI control
            LocalVar%GenArTq = PIController(LocalVar%VS_SpdErrAr, CntrPar%VS_KP(1), CntrPar%VS_KI(1), CntrPar%VS_MaxOMTq, CntrPar%VS_ArSatTq, LocalVar%DT, CntrPar%VS_MaxOMTq, LocalVar%piP, LocalVar%restart, objInst%instPI)
            LocalVar%GenBrTq = PIController(LocalVar%VS_SpdErrBr, CntrPar%VS_KP(1), CntrPar%VS_KI(1), CntrPar%VS_MinTq, CntrPar%VS_MinOMTq, LocalVar%DT, CntrPar%VS_MinOMTq, LocalVar%piP, LocalVar%restart, objInst%instPI)

            ! The action
            IF (LocalVar%VS_State == 1) THEN ! Region 1.5
                LocalVar%GenTq = LocalVar%GenBrTq
            ELSEIF (LocalVar%VS_State == 2) THEN ! Region 2
                LocalVar%GenTq = CntrPar%VS_Rgn2K*LocalVar%GenSpeedF*LocalVar%GenSpeedF
            ELSEIF (LocalVar%VS_State == 3) THEN ! Region 2.5
                LocalVar%GenTq = LocalVar%GenArTq
            ELSEIF (LocalVar%VS_State == 4) THEN ! Region 3, constant torque
                LocalVar%GenTq = CntrPar%VS_RtTq
            ELSEIF (LocalVar%VS_State == 5) THEN ! Region 3, constant power
                LocalVar%GenTq = (CntrPar%VS_RtPwr/(CntrPar%VS_GenEff/100.0))/LocalVar%GenSpeedF
            END IF

            ! Saturate
            LocalVar%GenTq = saturate(LocalVar%GenTq, CntrPar%VS_MinTq, CntrPar%VS_MaxTq)
        ELSE        ! VS_ControlMode of 0
            LocalVar%GenTq = 0
        ENDIF


        ! Saturate the commanded torque using the maximum torque limit:
        LocalVar%GenTq = MIN(LocalVar%GenTq, CntrPar%VS_MaxTq)                    ! Saturate the command using the maximum torque limit

        ! Saturate the commanded torque using the torque rate limit:
        LocalVar%GenTq = ratelimit(LocalVar%GenTq, -CntrPar%VS_MaxRat, CntrPar%VS_MaxRat, LocalVar%DT, LocalVar%restart, LocalVar%rlP,objInst%instRL)    ! Saturate the command using the torque rate limit

        ! Open loop torque control
        IF ((CntrPar%OL_Mode > 0) .AND. (CntrPar%Ind_GenTq > 0)) THEN
            ! Get current OL GenTq, applies for OL_Mode 1 and 2
            IF (LocalVar%Time >= CntrPar%OL_Breakpoints(1)) THEN
                LocalVar%GenTq = interp1d(CntrPar%OL_Breakpoints,CntrPar%OL_GenTq,LocalVar%Time,ErrVar)
            ENDIF

            ! Azimuth tracking control
            IF (CntrPar%OL_Mode == 2) THEN

                ! Push, pop and unwrap azimuth buffer
                ! Initialize
                IF (LocalVar%iStatus == 0) THEN
                    LocalVar%AzBuffer(1) = LocalVar%Azimuth
                    LocalVar%AzBuffer(2) = LocalVar%Azimuth
                ENDIF
                LocalVar%AzBuffer(1) = LocalVar%AzBuffer(2)
                LocalVar%AzBuffer(2) = LocalVar%Azimuth
                LocalVar%AzBuffer = UNWRAP(LocalVar%AzBuffer, ErrVar)
                LocalVar%AzUnwrapped = LocalVar%AzBuffer(2)

                ! Current desired Azimuth, error
                LocalVar%OL_Azimuth = interp1d(CntrPar%OL_Breakpoints,CntrPar%OL_Azimuth,LocalVar%Time,ErrVar)
                LocalVar%AzError = LocalVar%OL_Azimuth - LocalVar%AzUnwrapped

                LocalVar%GenTqAz = PIDController(LocalVar%AzError, CntrPar%RP_Gains(1), CntrPar%RP_Gains(2), CntrPar%RP_Gains(3), CntrPar%RP_Gains(4), -LocalVar%VS_MaxTq * 2, LocalVar%VS_MaxTq * 2, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst, LocalVar)
                LocalVar%GenTq = LocalVar%GenTq + LocalVar%GenTqAz

            ENDIF

        ENDIF

        ! Reset the value of LocalVar%VS_LastGenTrq to the current values:
        LocalVar%VS_LastGenTrq = LocalVar%GenTq
        LocalVar%VS_LastGenPwr = LocalVar%VS_GenPwr

        DebugVar%VS_GenTq = LocalVar%GenTq
        ! IF (LocalVar%n_DT >= CntrPar%Itim_SI .AND. LocalVar%n_DT <= CntrPar%Itim_SI+16000) THEN
        !     PRINT *, ' Post VS', DebugVar%VS_GenTq
        ! ENDIF
        ! Set the command generator torque (See Appendix A of Bladed User's Guide):
        avrSWAP(47) = MAX(0.0_DbKi, LocalVar%VS_LastGenTrq)  ! Demanded generator torque, prevent negatives.

        ! Add RoutineName to error message
        IF (ErrVar%aviFAIL < 0) THEN
            ErrVar%ErrMsg = RoutineName//':'//TRIM(ErrVar%ErrMsg)
        ENDIF

    END SUBROUTINE VariableSpeedControl
!---------------------------------------------------AGREGA FG------------------------------------------------------------------
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE SyntheticInertia(avrSWAP, CntrPar, LocalVar, DebugVar, objInst, ErrVar, PerfData)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances, PerformanceData, DebugVariables, ErrorVariables
        REAL(ReKi),                 INTENT(INOUT) :: avrSWAP(*)
        TYPE(ControlParameters),    INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),       INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),       INTENT(INOUT) :: DebugVar
        TYPE(ObjectInstances),      INTENT(INOUT) :: objInst
        TYPE(ErrorVariables),       INTENT(INOUT) :: ErrVar
        TYPE(PerformanceData),      INTENT(INOUT) :: PerfData

        CHARACTER(*), PARAMETER :: RoutineName = 'SyntheticInertia'

        ! ---- Cálculos previos comunes ----

        ! ---- Llamada a estrategia según modo ----
        SELECT CASE (CntrPar%IS_ControlMode)
        CASE (1)
            CALL SI_Tarnowski_GMFC(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        CASE (2)
            CALL SI_KOmega2(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        CASE (3)
            CALL SI_Ontario(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        CASE (4)
            CALL SI_Wang(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        CASE(5)
            CALL SI_GMFC(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        END SELECT

        ! ---- Post-procesamiento ----
        DebugVar%IS_status = LocalVar%IS_status

        LocalVar%GenTq = saturate(LocalVar%GenTq, CntrPar%VS_MinTq, LocalVar%VS_MaxTq)             
        LocalVar%GenTq = ratelimit(LocalVar%GenTq, -CntrPar%VS_MaxRat, CntrPar%VS_MaxRat, &
                                   LocalVar%DT, LocalVar%restart, LocalVar%rlP, objInst%instRL)

        LocalVar%IS_LastGenTrq = LocalVar%GenTq  !Si entra a SI, que se quede con el torque de la SI, sino va a ser el del VSC.
        LocalVar%VS_LastGenTrq = LocalVar%IS_LastGenTrq   ! Para los casos que entra a SI, que cuando lo use en el VSC, sea el torque del SI. Si no entra, va a ser lo mismo.
        LocalVar%VS_LastGenPwr = LocalVar%VS_GenPwr
        DebugVar%GenSpeedF_dot = (LocalVar%GenSpeedF_Last - LocalVar%GenSpeedF)/LocalVar%DT
        LocalVar%GenSpeedF_Last = LocalVar%GenSpeedF

        ! IF (LocalVar%n_DT >= CntrPar%Itim_SI .AND. LocalVar%n_DT <= CntrPar%Itim_SI+16000) THEN
        !     PRINT *, ' post SI', DebugVar%VS_GenTq
        ! ENDIF

        avrSWAP(47) = MAX(0.0_DbKi, LocalVar%IS_LastGenTrq)

        IF (ErrVar%aviFAIL < 0) THEN
            ErrVar%ErrMsg = RoutineName//':'//TRIM(ErrVar%ErrMsg)
        END IF
    END SUBROUTINE SyntheticInertia

!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE SI_Tarnowski_GMFC(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, PerformanceData, DebugVariables, ErrorVariables
        TYPE(ControlParameters), INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT) :: DebugVar
        TYPE(PerformanceData),   INTENT(INOUT) :: PerfData
        TYPE(ErrorVariables),    INTENT(INOUT) :: ErrVar
        REAL(DbKi)                  :: Tau_r            ! Estimated rotor torque [Nm]

        ! ---- Código específico de Tarnowski ----
        IF (CntrPar%VS_ConstPower == 1) THEN
            LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
        END IF
        Tau_r = AeroDynTorque(LocalVar%RotSpeedF, LocalVar%BlPitchCMeas, LocalVar, CntrPar, PerfData, ErrVar)
        LocalVar%Pmec_est = Tau_r*LocalVar%RotSpeedF/(CntrPar%VS_GenEff/100)  !Todo desde el LSS


        DebugVar%Pmec_est = LocalVar%Pmec_est  !FG:03/07/25
        DebugVar%Tau_r    = Tau_r !FG: 06/08/25

        ! -------- Tarnowski Strategy--------

        ! Optimal Tip-Speed-Ratio tracking controller
        IF ((CntrPar%IS_ControlMode == 1) .AND. (LocalVar%n_DT >= CntrPar%Itim_SI) .AND. (LocalVar%IS_ControlMode2 /= 1)) THEN
            ! Constant Power, update VS_MaxTq
            IF (CntrPar%VS_ConstPower == 1) THEN
                LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
            END IF

            IF (LocalVar%n_DT <= CntrPar%Ftim_SI) THEN
                ! Rampa de subida -- Paso 1: guardo variables pre IS
                ! IF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0)) THEN
                !     LocalVar%GenTq_Ti = LocalVar%GenTq      !Guardo las variables pre aplicación de IS
                !     LocalVar%OmegaTi = LocalVar%GenSpeedF

                !     LocalVar%Pgen_ref = LocalVar%GenTq * LocalVar%GenSpeedF + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1) * &
                !                         ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT / CntrPar%dt_rise)
                !     LocalVar%GenTq = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                !     IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                !     PRINT *, LocalVar%GenTq
                !     !LocalVar%GenTq = LocalVar%IS_LastGenTrq + CntrPar%VS_MaxRat * LocalVar%DT
                !     PRINT *, ' WARNING: Synthetic Inertia torque rate limit exceeded'
                !     END IF

                !     LocalVar%IS_status = 0.5
                ! !Rampa de subida -- mantengo hasta dt_rise
                ! ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0.5) .AND. (((LocalVar%n_DT - CntrPar%Itim_SI + 1)*LocalVar%DT / CntrPar%dt_rise) <= 1.0)) THEN       !Necesario para guardar las variables pre IS únicamente una vez

                !     LocalVar%Pgen_ref = LocalVar%GenTq_Ti * LocalVar%OmegaTi + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1) * &
                !                         ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT / CntrPar%dt_rise)
                !     LocalVar%GenTq = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                !     IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                !     !PRINT *, LocalVar%GenTq, LocalVar%IS_status, (LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT
                !    !LocalVar%GenTq = LocalVar%IS_LastGenTrq + CntrPar%VS_MaxRat * LocalVar%DT
                !     PRINT *, ' WARNING: Synthetic Inertia torque rate limit exceeded'
                !     END IF

                !     LocalVar%IS_status = 0.5

                !Escalón de mantenimiento  Paso 1
       !         ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0.5)) THEN
                IF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND.(LocalVar%IS_status == 0)) THEN
                    LocalVar%GenTq_Ti = LocalVar%GenTq      !Guardo las variables pre aplicación de IS
                    LocalVar%OmegaTi = LocalVar%GenSpeedF

                    LocalVar%Pgen_ref = LocalVar%GenTq_Ti * LocalVar%OmegaTi + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1)       !Aplicación de IS, tomo como base la P que tengo al momento de aplicarla.
                    LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                    IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque rate limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status
                    ELSEIF (LocalVar%GenTq > CntrPar%VS_MaxTq) THEN
                        LocalVar%GenTq = CntrPar%VS_MaxTq
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status
                    END IF

                    LocalVar%T_end_IS_Tar = LocalVar%n_DT * LocalVar%DT   ! Me va a guardar el paso en el que arranca la rampa de bajada
                    LocalVar%IS_status = 1

                !Escalón de mantenimiento
                ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 1)) THEN

                    LocalVar%Pgen_ref = LocalVar%GenTq_Ti * LocalVar%OmegaTi + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1)       !Aplicación de IS, tomo como base la P que tengo al momento de aplicarla.
                    LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                    IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque rate limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status
                    ELSEIF (LocalVar%GenTq > CntrPar%VS_MaxTq) THEN
                        LocalVar%GenTq = CntrPar%VS_MaxTq
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status
                    END IF

                    LocalVar%T_end_IS_Tar = LocalVar%n_DT * LocalVar%DT   ! Me va a guardar el paso en el que arranca la rampa de bajada
                    LocalVar%IS_status = 1

                    IF  ((LocalVar%n_DT >= CntrPar%Itim_SI + 1000) .AND. ((LocalVar%GenSpeedF - LocalVar%GenSpeedF_Last)>0)) THEN   ! Si pasaron X segundos y se está acelerando la turbina, salgo de la IS.
                        LocalVar%IS_status = 0 
                    END IF
                ! Rampa de bajada  !el fin lo seteo en la recuperación de Tarnowski
                ELSEIF (LocalVar%IS_status == 1 .AND. &
                        (((LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar) <= CntrPar%dt_rise)) THEN

                    !PRINT *, ' Entre a la rampa de bajada'
                    LocalVar%GenTq = ( ( ( LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery) ) - &
                        ( LocalVar%GenTq_Ti * LocalVar%OmegaTi * CntrPar%F_SI ) ) / CntrPar%dt_rise * &
                        ( (LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar ) + &
                        (CntrPar%F_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi) ) / LocalVar%GenSpeedF

                        LocalVar%IS_status = 1.5

                ELSEIF (LocalVar%IS_status == 1.5 .AND. &
                        (((LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar) <= CntrPar%dt_rise)) THEN

                    !PRINT *, ' Entre a la rampa de bajada'
                    LocalVar%GenTq = ( ( ( LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery) ) - &
                        ( LocalVar%GenTq_Ti * LocalVar%OmegaTi * CntrPar%F_SI ) ) / CntrPar%dt_rise * &
                        ( (LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar ) + &
                        (CntrPar%F_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi) ) / LocalVar%GenSpeedF

                        LocalVar%IS_status = 1.5
                !abs(Omega_Ti(1,t_step-1) - Omega_g) >= 1e-4  %Si omega esta variando menos de 1e-3 asumo que ya estabilizó y salgo.  ABS(LocalVar%GenSpeedF_Last - LocalVar%GenSpeedF) >= 0.0001
                !CFG 25/08 si dejo esto, va a querer retomar la velocidad pre SI que no tiene sentido con viento turbulento ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (LocalVar%IS_status /= 3)) THEN   ! Si pasa por acá sin haber pasado por los otros (viento bajo), el OmegaTi va a ser cero, asi que no actua
                !CFG 12/11 ELSEIF ((LocalVar%IS_LastGenTrq >= LocalVar%VS_LastGenTrq) .AND. LocalVar%IS_status /= 3) THEN  ! Si pasa por acá sin haber pasado por los otros (viento bajo), el OmegaTi va a ser cero, asi que no actua. CFG 10/11: compara el torque del VSControl con el del SI del paso anterior.
                !(LocalVar%VS_RefSpd >= LocalVar%GenSpeedF) .OR. (LocalVar%IS_LastGenTrq >= LocalVar%VS_LastGenTrq)
                
                !ELSEIF ( (LocalVar%VS_RefSpd >= LocalVar%GenSpeedF) .AND. (LocalVar%IS_status /= 3)) THEN
                ELSEIF ( (LocalVar%IS_LastGenTrq >= LocalVar%VS_LastGenTrq) .AND. (LocalVar%IS_status /= 3)) THEN
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = (LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery)) / LocalVar%GenSpeedF   !Recuperaciónde Tarnowski: utilizo estimación de Pmec.
                    !CFG 25/08: IF ((LocalVar%GenTq <= CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2) .AND. (CntrPar%TG /= 0)) THEN       ! Si el torque me queda por debajo de Komega2, me paso a eso (tiene que estar activa la flag TG).
                    ! IF (LocalVar%GenTq <= CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2) THEN   !momento en que me pasoLocalVar%GenTq <=  LocalVar%VS_LastGenTrq)
                    !     LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                    !     LocalVar%IS_status = 3
                    ! ENDIF
                !CFG 25/08: ELSEIF (LocalVar%GenSpeedF < LocalVar%OmegaTi) THEN
                !CFG 01/09 ELSEIF (LocalVar%GenTq >= LocalVar%VS_LastGenTrq) THEN
                !     LocalVar%IS_status = 3
                !     !CFG 25/08: LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                !     LocalVar%GenTq = LocalVar%VS_LastGenTrq
                    LocalVar%T_end_rec_Tar = LocalVar%n_DT * LocalVar%DT
                
                !ELSEIF (LocalVar%VS_LastGenTrq <= CntrPar%VS_Rgn2K *LocalVar%GenSpeedF**2 .AND. (LocalVar%IS_status == 3)) THEN
                ! ELSEIF (LocalVar%T_end_rec_Tar + 30 >= LocalVar%n_DT * LocalVar%DT) THEN
                !     LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                !     PRINT *, 'Entre a if nuevo'
                !     LocalVar%IS_status = 3
                ! CFG 11/11: fue peor el pico cuando retoma el control normal. ELSEIF ((LocalVar%IS_LastGenTrq < LocalVar%VS_LastGenTrq) .AND. LocalVar%IS_status /= 3 .AND. (LocalVar%n_DT <= (LocalVar%T_end_rec_Tar/LocalVar%DT) + 800)) THEN
                !     LocalVar%GenTq = (LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery)) / LocalVar%GenSpeedF
                !     PRINT *, 'ENTRE ACA'
                ELSE
                    LocalVar%IS_ControlMode2 = 1
                    LocalVar%IS_status = 0
                ENDIF
            !CFG 25/08: ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (LocalVar%IS_status /= 3)) THEN
            ELSEIF ((LocalVar%IS_LastGenTrq >= LocalVar%VS_LastGenTrq) .AND. (LocalVar%IS_status /= 3)) THEN
                LocalVar%IS_status = 2
                LocalVar%GenTq = (LocalVar%Pmec_est - CntrPar%VS_RtPwr * CntrPar%Frecovery) / LocalVar%GenSpeedF
                !CFG 10/11 IF ((LocalVar%GenTq <= LocalVar%VS_LastGenTrq) .AND. (CntrPar%TG /= 0)) THEN
                !     LocalVar%GenTq  = LocalVar%VS_LastGenTrq !CFG 01/09: CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                !     LocalVar%IS_status = 3
                ! END IF
            !CFG 25/08: ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (CntrPar%TG == 1)) THEN
            !CFG 01/09 ELSEIF ((LocalVar%GenTq >= LocalVar%VS_LastGenTrq) .AND. (CntrPar%TG == 1)) THEN
            !     LocalVar%IS_status = 3
            !     LocalVar%GenTq  = LocalVar%VS_LastGenTrq !CFG 01/09: CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
            ELSE
                LocalVar%IS_ControlMode2 = 1
                LocalVar%IS_status = 0
                !LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2   !TEST 25/08 CFG 10/11
            END IF
        END IF

    END SUBROUTINE SI_Tarnowski_GMFC

!-------------------------------------------------------------------------------------------------------------------------------

    SUBROUTINE SI_Tarnowski_LIBRO(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, PerformanceData, DebugVariables, ErrorVariables
        TYPE(ControlParameters), INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT) :: DebugVar
        TYPE(PerformanceData),   INTENT(INOUT) :: PerfData
        TYPE(ErrorVariables),    INTENT(INOUT) :: ErrVar
        REAL(DbKi)                  :: Tau_r            ! Estimated rotor torque [Nm]

        PRINT *, ' ENTRE A Tarnowski libro '
        ! ---- Código específico de Tarnowski ----
        IF (CntrPar%VS_ConstPower == 1) THEN
            LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
        END IF
        Tau_r = AeroDynTorque(LocalVar%RotSpeedF, LocalVar%BlPitchCMeas, LocalVar, CntrPar, PerfData, ErrVar)
        LocalVar%Pmec_est = Tau_r*LocalVar%RotSpeedF/(CntrPar%VS_GenEff/100)  !Todo desde el LSS


        DebugVar%Pmec_est = LocalVar%Pmec_est  !FG:03/07/25
        DebugVar%Tau_r    = Tau_r !FG: 06/08/25

        ! -------- Tarnowski Strategy--------
        ! Define max torque
        IF (LocalVar%VS_State == 4) THEN
            LocalVar%VS_MaxTq = CntrPar%VS_RtTq
        ELSE
            LocalVar%VS_MaxTq = CntrPar%VS_RtTq
        ENDIF

        ! Optimal Tip-Speed-Ratio tracking controller
        IF ((CntrPar%IS_ControlMode == 1) .AND. (LocalVar%n_DT >= CntrPar%Itim_SI) .AND. (LocalVar%IS_ControlMode2 /= 1)) THEN
            ! Constant Power, update VS_MaxTq
            IF (CntrPar%VS_ConstPower == 1) THEN
                LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
            END IF
            IF (LocalVar%n_DT <= CntrPar%Ftim_SI) THEN
                IF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0)) THEN
                    LocalVar%GenTq_Ti = LocalVar%GenTq    !Guardo el torque pre aplicación de IS

                    LocalVar%Pgen_ref = LocalVar%GenTq * LocalVar%GenSpeedF + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1)       !Aplicación de IS, tomo como base la P que tengo al momento de aplicarla.
                    LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                    IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq)/LocalVar%DT > CntrPar%VS_MaxRat) THEN
                        LocalVar%GenTq = LocalVar%IS_LastGenTrq + CntrPar%VS_MaxRat * LocalVar%DT
                        PRINT *, ' WARNING: Synthetic Inertia torque rate limit exceeded, limiting to ', LocalVar%GenTq
                    END IF

                    LocalVar%OmegaTi = LocalVar%GenSpeedF !Guardo la velocidad de giro en el instante que empieza la aplicación de IS.
                    LocalVar%IS_status = 1
                ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 1)) THEN
                    LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF    !Aplicación de IS, mantengo el escalón
                    LocalVar%T_end_IS_Tar = LocalVar%n_DT * LocalVar%DT
                    LocalVar%IS_status = 1

                ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (LocalVar%IS_status /= 3)) THEN   ! Si pasa por acá sin haber pasado por los otros (viento bajo), el OmegaTi va a ser cero, asi que no actua
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = (LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery)) / LocalVar%GenSpeedF   !Recuperaciónde Tarnowski: utilizo estimación de Pmec.
                    IF ((LocalVar%GenTq <= CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2) .AND. (CntrPar%TG /= 0)) THEN       ! Si el torque me queda por debajo de Komega2, me paso a eso (tiene que estar activa la flag TG).
                        LocalVar%GenTq  = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                        LocalVar%IS_status = 3
                    END IF
                ELSEIF (LocalVar%GenSpeedF < LocalVar%OmegaTi) THEN
                    LocalVar%IS_status = 3
                    LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                ELSE
                    LocalVar%IS_ControlMode2 = 1
                    LocalVar%IS_status = 0
                END IF
            ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (LocalVar%IS_status /= 3)) THEN
                LocalVar%IS_status = 2
                LocalVar%GenTq = (LocalVar%Pmec_est - CntrPar%VS_RtPwr * CntrPar%Frecovery) / LocalVar%GenSpeedF
                IF ((LocalVar%GenTq <= CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2) .AND. (CntrPar%TG /= 0)) THEN
                    LocalVar%GenTq  = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                    LocalVar%IS_status = 3
                END IF
            ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (CntrPar%TG == 1)) THEN
                LocalVar%IS_status = 3
                LocalVar%GenTq  = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
            ELSE
                LocalVar%IS_ControlMode2 = 1
                LocalVar%IS_status = 0
            END IF
        END IF

    END SUBROUTINE SI_Tarnowski_LIBRO

    !-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE SI_Ontario(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, PerformanceData, DebugVariables, ErrorVariables
        TYPE(ControlParameters), INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT) :: DebugVar
        TYPE(PerformanceData),   INTENT(INOUT) :: PerfData
        TYPE(ErrorVariables),    INTENT(INOUT) :: ErrVar
        REAL(DbKi)                  :: R_SI

        R_SI = 0.9
        ! ---- Código específico de Ontario ----
        IF ((CntrPar%IS_ControlMode == 3) .AND. (LocalVar%n_DT >= CntrPar%Itim_SI) .AND. (LocalVar%IS_ControlMode2 /= 1)) THEN
            ! Limitar potencia si está activo el modo de potencia constante
            IF (CntrPar%VS_ConstPower == 1) THEN
                LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
            END IF

            IF (LocalVar%n_DT <= CntrPar%Ftim_SI) THEN

                ! Rampa de subida
                IF ((LocalVar%IS_status == 0)) THEN
                    LocalVar%GenTq_Ti = LocalVar%GenTq

                    LocalVar%Pgen_ref = LocalVar%GenTq * LocalVar%GenSpeedF + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1) * &
                                        ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT / CntrPar%dt_rise)
                    LocalVar%GenTq = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                    LocalVar%OmegaTi = LocalVar%GenSpeedF
                    LocalVar%IS_status = 0.5

                ! Escalón paso inicial
                ELSEIF ((LocalVar%IS_status == 0.5) .AND. &
                    (((LocalVar%n_DT - CntrPar%Itim_SI + 1)*LocalVar%DT / CntrPar%dt_rise) <= 1.0)) THEN

                    LocalVar%Pgen_ref = LocalVar%GenTq * LocalVar%OmegaTi * (1 + (CntrPar%F_SI - 1) * &
                                        ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT / CntrPar%dt_rise))
                    LocalVar%GenTq = LocalVar%Pgen_ref / LocalVar%GenSpeedF
                    LocalVar%IS_status = 0.5

                ! Escalón mantenido -- paso 1
                ELSEIF (LocalVar%IS_status == 0.5 .AND. &
                        ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT <= CntrPar%end_Ontario_step)) THEN
                    LocalVar%GenTq = (LocalVar%GenTq_Ti * LocalVar%OmegaTi * CntrPar%F_SI) / LocalVar%GenSpeedF
                    LocalVar%IS_status = 1
                ! Escalón mantenido
                ELSEIF (LocalVar%IS_status == 1 .AND. &
                        ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT <= CntrPar%end_Ontario_step)) THEN
                    LocalVar%GenTq = (LocalVar%GenTq_Ti * LocalVar%OmegaTi * CntrPar%F_SI) / LocalVar%GenSpeedF
                    LocalVar%IS_status = 1

                ! Rampa de bajada  paso1
                ELSEIF ((LocalVar%IS_status == 1) .AND. ((LocalVar%n_DT * LocalVar%DT) - (CntrPar%Itim_SI + CntrPar%dt_rise + CntrPar%end_Ontario_step) <= CntrPar%dt_rise)) THEN

                    !PRINT *, ' Entre a la rampa de bajada'
                    LocalVar%GenTq = ( ( LocalVar%GenTq_Ti * LocalVar%OmegaTi * (R_SI - CntrPar%F_SI) / CntrPar%dt_rise * &
                        ( ((LocalVar%n_DT - CntrPar%Itim_SI) * LocalVar%DT) - CntrPar%end_Ontario_step ) + &
                        ( CntrPar%F_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi ) ) / LocalVar%GenSpeedF )

                        LocalVar%IS_status = 1.5
                ! Rampa de bajada
                ELSEIF ((LocalVar%IS_status == 1.5) .AND. ((LocalVar%n_DT * LocalVar%DT) - ((CntrPar%Itim_SI* LocalVar%DT) + CntrPar%end_Ontario_step) <= CntrPar%dt_rise)) THEN

                    LocalVar%GenTq = ( ( LocalVar%GenTq_Ti * LocalVar%OmegaTi * (R_SI - CntrPar%F_SI) / CntrPar%dt_rise * &
                        ( ((LocalVar%n_DT - CntrPar%Itim_SI) * LocalVar%DT) - CntrPar%end_Ontario_step ) + &
                        ( CntrPar%F_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi ) ) / LocalVar%GenSpeedF )

                        LocalVar%IS_status = 1.5

                !Recuperación
                ELSEIF (LocalVar%GenSpeedF < LocalVar%OmegaTi .AND. LocalVar%IS_status /= 3) THEN
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = (R_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi) / LocalVar%GenSpeedF   !Recuperación Ontario

                    IF ((LocalVar%GenTq <= CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2) .AND. (CntrPar%TG /= 0)) THEN
                        LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                        LocalVar%IS_status = 3
                    END IF

                ELSEIF (LocalVar%GenSpeedF < LocalVar%OmegaTi .AND. CntrPar%TG == 1) THEN
                    LocalVar%IS_status = 3
                    LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2

                ELSE
                    LocalVar%IS_ControlMode2 = 1
                    LocalVar%IS_status = 0
                END IF

            ! Recuperación fuera del intervalo IS
            ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (LocalVar%IS_status /= 3)) THEN
                LocalVar%IS_status = 2
                LocalVar%GenTq = (R_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi) / LocalVar%GenSpeedF   !Recuperación Ontario
                IF ((LocalVar%GenTq <= CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2) .AND. (CntrPar%TG /= 0)) THEN
                    LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2
                    LocalVar%IS_status = 3
                END IF

            ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi) .AND. (CntrPar%TG == 1)) THEN
                LocalVar%IS_status = 3
                LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2

            ELSE
                LocalVar%IS_ControlMode2 = 1
                LocalVar%IS_status = 0
            END IF

        END IF

    END SUBROUTINE SI_Ontario

!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE SI_Wang(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, PerformanceData, DebugVariables, ErrorVariables
        TYPE(ControlParameters), INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT) :: DebugVar
        TYPE(PerformanceData),   INTENT(INOUT) :: PerfData
        TYPE(ErrorVariables),    INTENT(INOUT) :: ErrVar

        ! Parámetros Wang
        REAL(DbKi)            :: TimDecreaseTor = 20.0_DbKi       ! [s] duración B-C
        REAL(DbKi), PARAMETER :: dPowerDecrease = 0.01_DbKi        ! [p.u./s]
        REAL(DbKi), PARAMETER :: TimeStatus4   = 60.0_DbKi         ! [s]
        REAL(DbKi), PARAMETER :: FomegaMinWang = 0.4_DbKi          ! mín. vel. rotor (p.u.)

        REAL(DbKi) :: omega, OmRated, Kg, Mgen_max, Prated
        REAL(DbKi) :: P_TLIC
        INTEGER :: ntime
        REAL(DbKi), SAVE :: ItimeStatus4 = 0.0_DbKi   ! tiempo inicio estado 4

        ! Map variables
        omega     = LocalVar%GenSpeedF
        OmRated   = CntrPar%VS_RefSpd
        Kg        = CntrPar%VS_Rgn2K
        Mgen_max  = CntrPar%VS_MaxTq
        Prated    = CntrPar%VS_RtPwr
        ntime     = LocalVar%n_DT

        ! IF ((LocalVar%BlPitch(1) * 57.295780 > CntrPar%PC_FinePit) .OR. (LocalVar%BlPitch(2) * 57.295780 > CntrPar%PC_FinePit) .OR. (LocalVar%BlPitch(3) * 57.295780 > CntrPar%PC_FinePit)) THEN
        !     TimDecreaseTor = 5_DbKi     ! For region III
        ! ENDIF

        ! ---- Region 2 synthetic inertia Stepwise Wang ----
        IF (CntrPar%IS_ControlMode == 4 .AND. ntime >= CntrPar%Itim_SI) THEN

            IF (ntime <= CntrPar%Ftim_SI) THEN
                ! A-B
                IF (omega > OmRated*FomegaMinWang .AND. LocalVar%IS_status == 0) THEN
                    P_TLIC = (Mgen_max*omega - Kg*(OmRated*FomegaMinWang)**3) * &
                            (omega - OmRated*FomegaMinWang) / (omega - OmRated*FomegaMinWang) + &
                            Kg*(OmRated*FomegaMinWang)**3
                    LocalVar%GenTq = P_TLIC / omega
                    LocalVar%IS_status = 1
                    LocalVar%OmegaTi = omega
                !  PRINT *, ' GenTq ', LocalVar%GenTq , LocalVar%IS_status

                ! B-C
                ELSEIF (omega > OmRated*FomegaMinWang .AND. (ntime - CntrPar%Itim_SI)*LocalVar%DT < TimDecreaseTor .AND. &
                        LocalVar%IS_status == 1) THEN
                    P_TLIC = (Mgen_max*LocalVar%OmegaTi - Kg*(OmRated*FomegaMinWang)**3) * &
                            (omega - OmRated*FomegaMinWang) / (LocalVar%OmegaTi - OmRated*FomegaMinWang) + &
                            Kg*(OmRated*FomegaMinWang)**3
                    LocalVar%GenTq = P_TLIC / omega
                    LocalVar%Last_omega = omega
                ! PRINT *, ' GenTq ', LocalVar%GenTq , LocalVar%IS_status

                ! C-D
                !ELSEIF (LocalVar%GenSpeedF_Last > omega .AND. LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last > Kg*omega**3 .AND. &
                ELSEIF (LocalVar%GenSpeedF_Last > omega .AND. LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last > LocalVar%VS_LastGenTrq*omega .AND. &
                        LocalVar%IS_status /= 4) THEN
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = LocalVar%IS_LastGenTrq - Prated*dPowerDecrease*LocalVar%DT/omega
                !  PRINT *, ' Torque ', LocalVar%GenTq, 'Komega2', Kg*omega**2

                ! D-E
                !ELSEIF (LocalVar%GenSpeedF_Last < omega .AND. LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last > Kg*omega**3 .AND. &
                ELSEIF (LocalVar%GenSpeedF_Last < omega .AND. LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last > LocalVar%VS_LastGenTrq*omega .AND. &
                        LocalVar%IS_status /= 4) THEN
                    LocalVar%GenTq = LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last/omega
                    LocalVar%IS_status = 3

                ! E-A inicio
                !ELSEIF (LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last <= Kg*omega**3) THEN
               !CFG 10/11 ! ELSEIF (LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last <= LocalVar%GenTq*omega) THEN
                !    ! LocalVar%GenTq = Kg*omega**2
                !     LocalVar%IS_status = 4
                !     ItimeStatus4 = REAL(ntime, DbKi)

                ! E-A
               !CFG 10/11: ELSEIF (LocalVar%IS_status == 4 .AND. (ntime - ItimeStatus4)*LocalVar%DT < TimeStatus4) THEN
               !     LocalVar%GenTq = Kg*omega**2

                ELSE
                    CntrPar%IS_ControlMode = 0
                    LocalVar%IS_status = 0
                END IF

            ! ---- After Ftim_SI ---- 
            ELSE
                ! C-D
                IF (LocalVar%GenSpeedF_Last < omega .AND. LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last > LocalVar%VS_LastGenTrq*omega .AND. &
                    LocalVar%IS_status /= 4) THEN
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = LocalVar%IS_LastGenTrq - Prated*dPowerDecrease*LocalVar%DT/omega

                ! D-E
                ELSEIF (LocalVar%OmegaTi < omega .AND. LocalVar%IS_LastGenTrq*LocalVar%GenSpeedF_Last > LocalVar%VS_LastGenTrq*omega .AND. &
                        LocalVar%IS_status /= 4) THEN
                    LocalVar%GenTq = LocalVar%GenTq
                    LocalVar%IS_status = 3

                ! ! E-A inicio
                ! ELSEIF (LocalVar%IS_status == 3 .AND. LocalVar%GenTq*LocalVar%OmegaTi <= Kg*omega**3) THEN
                !     LocalVar%GenTq = Kg*omega**2
                !     LocalVar%IS_status = 4
                !     ItimeStatus4 = REAL(ntime, DbKi)

                ! ! E-A
                ! ELSEIF (LocalVar%IS_status == 4 .AND. (ntime - ItimeStatus4)*LocalVar%DT < TimeStatus4) THEN
                !     LocalVar%GenTq = Kg*omega**2

                ELSE
                    CntrPar%IS_ControlMode = 0
                    LocalVar%IS_status = 0
                END IF
            END IF
        END IF

    END SUBROUTINE SI_Wang

!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE SI_KOmega2(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, PerformanceData, DebugVariables, ErrorVariables
        TYPE(ControlParameters), INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT) :: DebugVar
        TYPE(PerformanceData),   INTENT(INOUT) :: PerfData
        TYPE(ErrorVariables),    INTENT(INOUT) :: ErrVar

        ! ---- Código específico de kω² recovery ----
        IF ((CntrPar%IS_ControlMode == 2) .AND. (LocalVar%n_DT >= CntrPar%Itim_SI) .AND. (LocalVar%IS_ControlMode2 /= 1)) THEN
            ! Constant Power, update VS_MaxTq
            IF (CntrPar%VS_ConstPower == 1) THEN
                LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
            END IF


            IF (LocalVar%n_DT <= CntrPar%Ftim_SI) THEN
                IF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0)) THEN
                    LocalVar%Pgen_ref = LocalVar%GenTq * LocalVar%GenSpeedF + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1)
                    LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF
                    LocalVar%OmegaTi = LocalVar%GenSpeedF !Guardo la velocidad de giro en el instante que empieza la aplicación de IS.
                    LocalVar%IS_status = 1
                ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 1)) THEN
                    LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi)) THEN
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF*LocalVar%GenSpeedF

                ELSE
                    LocalVar%IS_ControlMode2 = 1
                    LocalVar%IS_status = 0
                END IF

            ELSEIF ((LocalVar%GenSpeedF < LocalVar%OmegaTi)) THEN
                LocalVar%IS_status = 2
                LocalVar%GenTq  = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2

            ELSE
                LocalVar%IS_ControlMode2 = 1
                LocalVar%IS_status = 0
            END IF
        END IF
    END SUBROUTINE SI_KOmega2

SUBROUTINE SI_GMFC(CntrPar, LocalVar, DebugVar, PerfData, ErrVar)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, PerformanceData, DebugVariables, ErrorVariables
        TYPE(ControlParameters), INTENT(INOUT) :: CntrPar
        TYPE(LocalVariables),    INTENT(INOUT) :: LocalVar
        TYPE(DebugVariables),    INTENT(INOUT) :: DebugVar
        TYPE(PerformanceData),   INTENT(INOUT) :: PerfData
        TYPE(ErrorVariables),    INTENT(INOUT) :: ErrVar
        REAL(DbKi)                  :: Tau_r            ! Estimated rotor torque [Nm]

        ! ---- Código específico de estrategia GMFC ----
        IF (CntrPar%VS_ConstPower == 1) THEN
            LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
        END IF
        Tau_r = AeroDynTorque(LocalVar%RotSpeedF, LocalVar%BlPitchCMeas, LocalVar, CntrPar, PerfData, ErrVar)
        LocalVar%Pmec_est = Tau_r*LocalVar%RotSpeedF/(CntrPar%VS_GenEff/100)  !Todo desde el LSS
        

        DebugVar%Pmec_est = LocalVar%Pmec_est  
        DebugVar%Tau_r    = Tau_r 
        ! -------- GMFC Strategy--------

        ! Optimal Tip-Speed-Ratio tracking controller
        IF ((CntrPar%IS_ControlMode == 5) .AND. (LocalVar%n_DT >= CntrPar%Itim_SI) .AND. (LocalVar%IS_ControlMode2 /= 1)) THEN
            ! Constant Power, update VS_MaxTq
            IF (CntrPar%VS_ConstPower == 1) THEN
                LocalVar%VS_MaxTq = MIN((CntrPar%VS_RtPwr / (CntrPar%VS_GenEff / 100.0)) / LocalVar%GenSpeedF, CntrPar%VS_MaxTq)
            END IF

            IF (LocalVar%n_DT <= CntrPar%Ftim_SI) THEN
                !Rampa de subida -- Paso 1: guardo variables pre IS
                
                IF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0)) THEN
                    LocalVar%GenTq_Ti = LocalVar%GenTq      !Guardo las variables pre aplicación de IS
                    LocalVar%OmegaTi = LocalVar%GenSpeedF

                    LocalVar%GenSpeedF_dot_gmfc_strategy = (( (CntrPar%VS_RefSpd * CntrPar%F_omega_min) - LocalVar%GenSpeedF ) / CntrPar%Delta_T_over)
                    LocalVar%GenTq_end =  Tau_r/CntrPar%WE_GearboxRatio - CntrPar%WE_Jtot*LocalVar%GenSpeedF_dot_gmfc_strategy/(CntrPar%WE_GearboxRatio**2) 
                    PRINT *, 'Torque end:', LocalVar%GenTq_end
                    LocalVar%GenTq = LocalVar%GenTq_Ti + ((-LocalVar%GenTq_Ti + LocalVar%GenTq_end)  * &
                                        ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT / CntrPar%dt_rise))

                    IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                    PRINT *, LocalVar%GenTq
                    PRINT *, ' WARNING: Synthetic Inertia torque rate limit exceeded'
                    ELSEIF (LocalVar%GenTq > CntrPar%VS_MaxTq) THEN
                        LocalVar%GenTq = CntrPar%VS_MaxTq
                        PRINT *, ' WARNING: Synthetic Inertia torque limit exceeded'
                    END IF

                    LocalVar%IS_status = 0.5
                !Rampa de subida -- mantengo hasta dt_rise
                ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0.5) .AND. (((LocalVar%n_DT - CntrPar%Itim_SI + 1)*LocalVar%DT / CntrPar%dt_rise) <= 1.0)) THEN      
                    
                    !LocalVar%GenTq_end =  Tau_r/CntrPar%WE_GearboxRatio - CntrPar%WE_Jtot*LocalVar%GenSpeedF_dot_gmfc_strategy/(CntrPar%WE_GearboxRatio**2)
                    LocalVar%GenTq = LocalVar%GenTq_Ti +(-LocalVar%GenTq_Ti + LocalVar%GenTq_end) * &
                                        ((LocalVar%n_DT - CntrPar%Itim_SI + 1) * LocalVar%DT / CntrPar%dt_rise)
                    
                   IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                    PRINT *, LocalVar%GenTq
                    PRINT *, ' WARNING: Synthetic Inertia torque rate limit exceeded'
                    ELSEIF (LocalVar%GenTq > CntrPar%VS_MaxTq) THEN
                        LocalVar%GenTq = CntrPar%VS_MaxTq
                        PRINT *, ' WARNING: Synthetic Inertia torque limit exceeded'
                    END IF

                    LocalVar%IS_status = 0.5                      
                
                ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 0.5)) THEN
                    
                    !LocalVar%GenSpeedF_dot_gmfc_strategy = (( (CntrPar%VS_RefSpd * CntrPar%F_omega_min) - LocalVar%GenSpeedF ) / CntrPar%Delta_T_over)
                    PRINT *, 'DERIVADA-----', LocalVar%GenSpeedF_dot_gmfc_strategy 
                    LocalVar%GenTq =  Tau_r/CntrPar%WE_GearboxRatio - CntrPar%WE_Jtot*LocalVar%GenSpeedF_dot_gmfc_strategy/(CntrPar%WE_GearboxRatio**2) 
                    

                    IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque rate limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status, LocalVar%GenSpeedF_dot_gmfc_strategy
                    ELSEIF (LocalVar%GenTq > CntrPar%VS_MaxTq) THEN
                        LocalVar%GenTq = CntrPar%VS_MaxTq
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status
                    END IF

                    LocalVar%IS_status = 1

                !Escalón de mantenimiento  Paso 1
                ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 1)) THEN

                    LocalVar%GenTq =  Tau_r/CntrPar%WE_GearboxRatio - CntrPar%WE_Jtot*LocalVar%GenSpeedF_dot_gmfc_strategy/(CntrPar%WE_GearboxRatio**2)

                    IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT > CntrPar%VS_MaxRat) THEN
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque rate limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status, LocalVar%GenSpeedF_dot_gmfc_strategy
                    ELSEIF (LocalVar%GenTq > CntrPar%VS_MaxTq) THEN
                        LocalVar%GenTq = CntrPar%VS_MaxTq
                        PRINT *, ' Step 1: WARNING: Synthetic Inertia torque limit exceeded ', LocalVar%GenTq,  LocalVar%IS_status
                    END IF

                    LocalVar%T_end_IS_Tar = LocalVar%n_DT * LocalVar%DT   ! Me va a guardar el paso en el que arranca la rampa de bajada
                    LocalVar%IS_status = 1

                ! !Escalón de mantenimiento
                ! ELSEIF ((LocalVar%GenSpeedF > CntrPar%VS_RefSpd * CntrPar%F_omega_min) .AND. (LocalVar%IS_status == 1)) THEN

                !     LocalVar%Pgen_ref = LocalVar%GenTq_Ti * LocalVar%OmegaTi + CntrPar%VS_RtPwr * (CntrPar%F_SI - 1)       !Aplicación de IS, tomo como base la P que tengo al momento de aplicarla.
                !     LocalVar%GenTq  = LocalVar%Pgen_ref / LocalVar%GenSpeedF

                !     IF ((LocalVar%GenTq - LocalVar%IS_LastGenTrq)/LocalVar%DT > CntrPar%VS_MaxRat) THEN
                !     PRINT *, LocalVar%GenTq, (LocalVar%GenTq - LocalVar%IS_LastGenTrq) / LocalVar%DT
                !     LocalVar%GenTq = LocalVar%IS_LastGenTrq + CntrPar%VS_MaxRat * LocalVar%DT
                !     PRINT *, ' WARNING: Synthetic Inertia torque rate limit exceeded, limiting to ', LocalVar%GenTq,  LocalVar%IS_status
                !     END IF

                !     LocalVar%T_end_IS_Tar = LocalVar%n_DT * LocalVar%DT   ! Me va a guardar el paso en el que arranca la rampa de bajada
                !     LocalVar%IS_status = 1

                ! ! Rampa de bajada  !el fin lo seteo en la recuperación de Tarnowski
                ELSEIF (LocalVar%IS_status == 1 .AND. &
                        (((LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar) <= CntrPar%dt_rise)) THEN

                    !PRINT *, ' Entre a la rampa de bajada'
                    LocalVar%GenTq = ( ( ( LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery) ) - &
                        ( LocalVar%GenTq_Ti * LocalVar%OmegaTi * CntrPar%F_SI ) ) / CntrPar%dt_rise * &
                        ( (LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar ) + &
                        (CntrPar%F_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi) ) / LocalVar%GenSpeedF

                        LocalVar%IS_status = 1.5

                ELSEIF (LocalVar%IS_status == 1.5 .AND. &           !ARREGLAR RAMPA----NO ES CORRECTA PARA LA ESTRATEGIA, USA LA MISMA QUE TARNOWSKI ACA
                        (((LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar) <= CntrPar%dt_rise)) THEN

                    !PRINT *, ' Entre a la rampa de bajada'
                    LocalVar%GenTq = ( ( ( LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery) ) - &
                        ( LocalVar%GenTq_Ti * LocalVar%OmegaTi * CntrPar%F_SI ) ) / CntrPar%dt_rise * &
                        ( (LocalVar%n_DT * LocalVar%DT) - LocalVar%T_end_IS_Tar ) + &
                        (CntrPar%F_SI * LocalVar%GenTq_Ti * LocalVar%OmegaTi) ) / LocalVar%GenSpeedF

                        LocalVar%IS_status = 1.5
                ELSEIF ((LocalVar%GenTq >= LocalVar%VS_LastGenTrq) .AND. LocalVar%IS_status /= 3) THEN  !viento bajo), el OmegaTi va a ser cero, asi que no actua
                    LocalVar%IS_status = 2
                    LocalVar%GenTq = (LocalVar%Pmec_est - (CntrPar%VS_RtPwr * CntrPar%Frecovery)) / LocalVar%GenSpeedF   !Recuperaciónde Tarnowski: utilizo estimación de Pmec.
                    IF ((LocalVar%GenTq <= LocalVar%VS_LastGenTrq) .AND. (CntrPar%TG /= 0)) THEN
                        LocalVar%GenTq  = LocalVar%VS_LastGenTrq 
                        LocalVar%IS_status = 3
                    END IF
                
                ELSE
                    LocalVar%IS_ControlMode2 = 1
                    LocalVar%IS_status = 0
                ENDIF
            ELSEIF ((LocalVar%GenTq >= LocalVar%VS_LastGenTrq) .AND. (LocalVar%IS_status /= 3)) THEN
                LocalVar%IS_status = 2
                LocalVar%GenTq = (LocalVar%Pmec_est - CntrPar%VS_RtPwr * CntrPar%Frecovery) / LocalVar%GenSpeedF
                IF ((LocalVar%GenTq <= LocalVar%VS_LastGenTrq) .AND. (CntrPar%TG /= 0)) THEN
                    LocalVar%GenTq  = LocalVar%VS_LastGenTrq 
                    LocalVar%IS_status = 3
                END IF
            
            ELSE
                PRINT *, ' Entre en el ELSE linea 1020'
                LocalVar%IS_ControlMode2 = 1
                LocalVar%IS_status = 0
                LocalVar%GenTq = CntrPar%VS_Rgn2K * LocalVar%GenSpeedF**2   
            END IF
        END IF

    END SUBROUTINE SI_GMFC
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE YawRateControl(avrSWAP, CntrPar, LocalVar, objInst, DebugVar, ErrVar)
        ! Yaw rate controller
        !       Y_ControlMode = 0, No yaw control
        !       Y_ControlMode = 1, Yaw rate control using yaw drive

        ! TODO: Lots of R2D->D2R, this should be cleaned up.
        ! TODO: The constant offset implementation is sort of circular here as a setpoint is already being defined in SetVariablesSetpoints. This could also use cleanup
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances, DebugVariables, ErrorVariables

        REAL(ReKi), INTENT(INOUT) :: avrSWAP(*) ! The swap array, used to pass data to, and receive data from, the DLL controller.

        TYPE(ControlParameters), INTENT(INOUT)    :: CntrPar
        TYPE(LocalVariables), INTENT(INOUT)       :: LocalVar
        TYPE(ObjectInstances), INTENT(INOUT)      :: objInst
        TYPE(DebugVariables), INTENT(INOUT)       :: DebugVar
        TYPE(ErrorVariables), INTENT(INOUT)       :: ErrVar

        ! Allocate Variables
        REAL(DbKi), SAVE :: NacVaneOffset                          ! For offset control
        INTEGER, SAVE :: YawState                               ! Yawing left(-1), right(1), or stopped(0)
        REAL(DbKi)       :: WindDir                                ! Instantaneous wind dind direction, equal to turbine nacelle heading plus the measured vane angle (deg)
        REAL(DbKi)       :: WindDirPlusOffset                     ! Instantaneous wind direction minus the assigned vane offset (deg)
        REAL(DbKi)       :: WindDirPlusOffsetCosF                 ! Time-filtered x-component of WindDirPlusOffset (deg)
        REAL(DbKi)       :: WindDirPlusOffsetSinF                 ! Time-filtered y-component of WindDirPlusOffset (deg)
        REAL(DbKi)       :: NacHeadingTarget                       ! Time-filtered wind direction minus the assigned vane offset (deg)
        REAL(DbKi), SAVE :: NacHeadingError                        ! Yaw error (deg)
        REAL(DbKi)       :: YawRateCom                             ! Commanded yaw rate (deg/s)
        REAL(DbKi)       :: deadband                               ! Allowable yaw error deadband (deg)
        REAL(DbKi)       :: Time                                   ! Current time
        INTEGER, SAVE :: Tidx                                   ! Index i: commanded yaw error is interpolated between i and i+1

        IF (CntrPar%Y_ControlMode == 1) THEN

            ! Compass wind directions in degrees
            WindDir = wrap_360(LocalVar%NacHeading + LocalVar%NacVane)

            ! Initialize
            IF (LocalVar%iStatus == 0) THEN
                YawState = 0
                Tidx = 1
            ENDIF

            ! Compute/apply offset
            IF (CntrPar%ZMQ_Mode == 1) THEN
                NacVaneOffset = LocalVar%ZMQ_YawOffset
            ELSE
                NacVaneOffset = CntrPar%Y_MErrSet ! (deg) # Offset from setpoint
            ENDIF

            ! Update filtered wind direction
            WindDirPlusOffset = wrap_360(WindDir + NacVaneOffset) ! (deg)
            WindDirPlusOffsetCosF = LPFilter(cos(WindDirPlusOffset*D2R), LocalVar%DT, CntrPar%F_YawErr, LocalVar%FP, LocalVar%iStatus, .FALSE., objInst%instLPF) ! (-)
            WindDirPlusOffsetSinF = LPFilter(sin(WindDirPlusOffset*D2R), LocalVar%DT, CntrPar%F_YawErr, LocalVar%FP, LocalVar%iStatus, .FALSE., objInst%instLPF) ! (-)
            NacHeadingTarget = wrap_360(atan2(WindDirPlusOffsetSinF, WindDirPlusOffsetCosF) * R2D) ! (deg)

            ! ---- Now get into the guts of the control ----
            ! Yaw error
            NacHeadingError = wrap_180(NacHeadingTarget - LocalVar%NacHeading)

            ! Check for deadband
            IF (LocalVar%WE_Vw_F .le. CntrPar%Y_uSwitch) THEN
                deadband = CntrPar%Y_ErrThresh(1)
            ELSE
                deadband = CntrPar%Y_ErrThresh(2)
            ENDIF

            ! yawing right
            IF (YawState == 1) THEN
                IF (NacHeadingError .le. 0) THEN
                    ! stop yawing
                    YawRateCom = 0.0
                    YawState = 0
                ELSE
                    ! persist
                    LocalVar%NacHeading = wrap_360(LocalVar%NacHeading + CntrPar%Y_Rate*LocalVar%DT)
                    YawRateCom = CntrPar%Y_Rate
                    YawState = 1
                ENDIF
            ! yawing left
            ELSEIF (YawState == -1) THEN
                IF (NacHeadingError .ge. 0) THEN
                    ! stop yawing
                    YawRateCom = 0.0
                    YawState = 0
                ELSE
                    ! persist
                    LocalVar%NacHeading = wrap_360(LocalVar%NacHeading - CntrPar%Y_Rate*LocalVar%DT)
                    YawRateCom = -CntrPar%Y_Rate
                    YawState = -1
                ENDIF
            ! Initiate yaw if outside yaw error threshold
            ELSE
                IF (NacHeadingError .gt. deadband) THEN
                    YawState = 1 ! yaw right
                ENDIF

                IF (NacHeadingError .lt. -deadband) THEN
                    YawState = -1 ! yaw left
                ENDIF

                YawRateCom = 0.0 ! if YawState is not 0, start yawing on the next time step
            ENDIF

            ! Output yaw rate command in rad/s
            avrSWAP(48) = YawRateCom * D2R

            ! If using open loop yaw rate control, overwrite controlled output
            ! Open loop yaw rate control - control input in rad/s
            IF ((CntrPar%OL_Mode > 0) .AND. (CntrPar%Ind_YawRate > 0)) THEN
                IF (LocalVar%Time >= CntrPar%OL_Breakpoints(1)) THEN
                    avrSWAP(48) = interp1d(CntrPar%OL_Breakpoints,CntrPar%OL_YawRate,LocalVar%Time, ErrVar)
                ENDIF
            ENDIF

            ! Save for debug
            DebugVar%YawRateCom       = YawRateCom
            DebugVar%NacHeadingTarget = NacHeadingTarget
            DebugVar%NacVaneOffset    = NacVaneOffset
            DebugVar%YawState         = YawState
            DebugVar%Yaw_Err          = NacHeadingError
        END IF
    END SUBROUTINE YawRateControl
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE IPC(CntrPar, LocalVar, objInst, DebugVar, ErrVar)
        ! Individual pitch control subroutine
        !   - Calculates the commanded pitch angles for IPC employed for blade fatigue load reductions at 1P and 2P
        !   - Includes yaw by IPC

        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances, DebugVariables, ErrorVariables

        TYPE(ControlParameters),    INTENT(INOUT)       :: CntrPar
        TYPE(LocalVariables),       INTENT(INOUT)       :: LocalVar
        TYPE(ObjectInstances),      INTENT(INOUT)       :: objInst
        TYPE(DebugVariables),       INTENT(INOUT)        :: DebugVar
        TYPE(ErrorVariables),       INTENT(INOUT)        :: ErrVar

        ! Local variables
        REAL(DbKi)                  :: PitComIPC(3), PitComIPCF(3), PitComIPC_1P(3), PitComIPC_2P(3)
        INTEGER(IntKi)              :: i, K                                    ! Integer used to loop through gains and turbine blades
        REAL(DbKi)                  :: axisYawIPC_1P                           ! IPC contribution with yaw-by-IPC component
        REAL(DbKi)                  :: Y_MErr, Y_MErrF, Y_MErrF_IPC            ! Unfiltered and filtered yaw alignment error [rad]

        CHARACTER(*),               PARAMETER           :: RoutineName = 'IPC'

        ! Body
        ! Pass rootMOOPs through the Coleman transform to get the tilt and yaw moment axis
        CALL ColemanTransform(LocalVar%rootMOOPF, LocalVar%Azimuth, NP_1, LocalVar%axisTilt_1P, LocalVar%axisYaw_1P)
        CALL ColemanTransform(LocalVar%rootMOOPF, LocalVar%Azimuth, NP_2, LocalVar%axisTilt_2P, LocalVar%axisYaw_2P)

        ! High-pass filter the MBC yaw component and filter yaw alignment error, and compute the yaw-by-IPC contribution
        IF (CntrPar%Y_ControlMode == 2) THEN
            Y_MErr = wrap_360(LocalVar%NacHeading + LocalVar%NacVane)
            Y_MErrF = LPFilter(Y_MErr, LocalVar%DT, CntrPar%F_YawErr, LocalVar%FP, LocalVar%iStatus, LocalVar%restart, objInst%instSecLPF)
            Y_MErrF_IPC = PIController(Y_MErrF, CntrPar%Y_IPC_KP, CntrPar%Y_IPC_KI, -CntrPar%Y_IPC_IntSat, CntrPar%Y_IPC_IntSat, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
        ELSE
            LocalVar%axisYawF_1P = LocalVar%axisYaw_1P
            Y_MErrF = 0.0
            Y_MErrF_IPC = 0.0
        END IF

        ! Soft cutin with sigma function
        DO i = 1,2
            LocalVar%IPC_KP(i) = sigma(LocalVar%WE_Vw, CntrPar%IPC_Vramp(1), CntrPar%IPC_Vramp(2), 0.0_DbKi, CntrPar%IPC_KP(i), ErrVar)
            LocalVar%IPC_KI(i) = sigma(LocalVar%WE_Vw, CntrPar%IPC_Vramp(1), CntrPar%IPC_Vramp(2), 0.0_DbKi, CntrPar%IPC_KI(i), ErrVar)
        END DO

        ! Handle saturation limit, depends on IPC_SatMode
        IF (CntrPar%IPC_SatMode == 2) THEN
            ! Saturate to min allowed pitch angle, softly using IPC_IntSat
            LocalVar%IPC_IntSat = min(CntrPar%IPC_IntSat,LocalVar%BlPitchCMeas - CntrPar%PC_MinPit)
        ELSEIF (CntrPar%IPC_SatMode == 3) THEN
            ! Saturate to peak shaving, softly using IPC_IntSat
            LocalVar%IPC_IntSat = min(CntrPar%IPC_IntSat,LocalVar%BlPitchCMeas - LocalVar%PC_MinPit)
        ELSE
            LocalVar%IPC_IntSat = CntrPar%IPC_IntSat
        ENDIF

        ! Integrate the signal and multiply with the IPC gain
        IF (CntrPar%IPC_ControlMode >= 1 .AND. CntrPar%Y_ControlMode /= 2)  THEN
            LocalVar%IPC_axisTilt_1P = PIController(LocalVar%axisTilt_1P, LocalVar%IPC_KP(1), LocalVar%IPC_KI(1), -LocalVar%IPC_IntSat, LocalVar%IPC_IntSat, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
            LocalVar%IPC_axisYaw_1P = PIController(LocalVar%axisYawF_1P, LocalVar%IPC_KP(1), LocalVar%IPC_KI(1), -LocalVar%IPC_IntSat, LocalVar%IPC_IntSat, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)

            IF (CntrPar%IPC_ControlMode >= 2) THEN
                LocalVar%IPC_axisTilt_2P = PIController(LocalVar%axisTilt_2P, LocalVar%IPC_KP(2), LocalVar%IPC_KI(2), -LocalVar%IPC_IntSat, LocalVar%IPC_IntSat, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
                LocalVar%IPC_axisYaw_2P = PIController(LocalVar%axisYawF_2P, LocalVar%IPC_KP(2), LocalVar%IPC_KI(2), -LocalVar%IPC_IntSat, LocalVar%IPC_IntSat, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
            END IF
        ELSE
            LocalVar%IPC_axisTilt_1P = 0.0
            LocalVar%IPC_axisYaw_1P = 0.0
            LocalVar%IPC_axisTilt_2P = 0.0
            LocalVar%IPC_axisYaw_2P = 0.0
        ENDIF

        ! Add the yaw-by-IPC contribution
        axisYawIPC_1P = LocalVar%IPC_axisYaw_1P + Y_MErrF_IPC

        ! Pass direct and quadrature axis through the inverse Coleman transform to get the commanded pitch angles
        CALL ColemanTransformInverse(LocalVar%IPC_axisTilt_1P, axisYawIPC_1P, LocalVar%Azimuth, NP_1, CntrPar%IPC_aziOffset(1), PitComIPC_1P)
        CALL ColemanTransformInverse(LocalVar%IPC_axisTilt_2P, LocalVar%IPC_axisYaw_2P, LocalVar%Azimuth, NP_2, CntrPar%IPC_aziOffset(2), PitComIPC_2P)

        ! Sum nP IPC contributions and store to LocalVar data type
        DO K = 1,LocalVar%NumBl
            PitComIPC(K) = PitComIPC_1P(K) + PitComIPC_2P(K)

            ! Optionally filter the resulting signal to induce a phase delay
            IF (CntrPar%IPC_CornerFreqAct > 0.0) THEN
                PitComIPCF(K) = LPFilter(PitComIPC(K), LocalVar%DT, CntrPar%IPC_CornerFreqAct, LocalVar%FP, LocalVar%iStatus, LocalVar%restart, objInst%instLPF)
            ELSE
                PitComIPCF(K) = PitComIPC(K)
            END IF

            LocalVar%IPC_PitComF(K) = PitComIPCF(K)
        END DO


        ! Add RoutineName to error message
        IF (ErrVar%aviFAIL < 0) THEN
            ErrVar%ErrMsg = RoutineName//':'//TRIM(ErrVar%ErrMsg)
        ENDIF

    END SUBROUTINE IPC
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE ForeAftDamping(CntrPar, LocalVar, objInst)
        ! Fore-aft damping controller, reducing the tower fore-aft vibrations using pitch

        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances

        ! Local variables
        INTEGER(IntKi) :: K    ! Integer used to loop through turbine blades

        TYPE(ControlParameters), INTENT(INOUT)  :: CntrPar
        TYPE(LocalVariables), INTENT(INOUT)     :: LocalVar
        TYPE(ObjectInstances), INTENT(INOUT)    :: objInst

        ! Body
        LocalVar%FA_AccHPFI = PIController(LocalVar%FA_AccHPF, 0.0_DbKi, CntrPar%FA_KI, -CntrPar%FA_IntSat, CntrPar%FA_IntSat, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)

        ! Store the fore-aft pitch contribution to LocalVar data type
        DO K = 1,LocalVar%NumBl
            LocalVar%FA_PitCom(K) = LocalVar%FA_AccHPFI
        END DO

    END SUBROUTINE ForeAftDamping
!-------------------------------------------------------------------------------------------------------------------------------
    REAL(DbKi) FUNCTION FloatingFeedback(LocalVar, CntrPar, objInst, ErrVar)
    ! FloatingFeedback defines a minimum blade pitch angle based on a lookup table provided by DISON.IN
    !       Fl_Mode = 0, No feedback
    !       Fl_Mode = 1, Proportional feedback of nacelle velocity (translational)
    !       Fl_Mode = 2, Proportional feedback of nacelle velocity (rotational)
        USE ROSCO_Types, ONLY : LocalVariables, ControlParameters, ObjectInstances, ErrorVariables
        IMPLICIT NONE
        ! Inputs
        TYPE(ControlParameters), INTENT(IN)     :: CntrPar
        TYPE(LocalVariables), INTENT(INOUT)     :: LocalVar
        TYPE(ObjectInstances), INTENT(INOUT)    :: objInst
        TYPE(ErrorVariables), INTENT(INOUT)     :: ErrVar
        ! Allocate Variables
        REAL(DbKi)                      :: FA_vel ! Tower fore-aft velocity [m/s]
        REAL(DbKi)                      :: NacIMU_FA_vel ! Tower fore-aft pitching velocity [rad/s]

        ! Gain scheduling
        LocalVar%Kp_Float = interp1d(CntrPar%Fl_U,CntrPar%Fl_Kp,LocalVar%WE_Vw_F,ErrVar)       ! Schedule based on WSE

        ! Calculate floating contribution to pitch command
        FA_vel = PIController(LocalVar%FA_AccF, 0.0_DbKi, 1.0_DbKi, -100.0_DbKi , 100.0_DbKi ,LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI) ! NJA: should never reach saturation limits....
        NacIMU_FA_vel = PIController(LocalVar%NacIMU_FA_AccF, 0.0_DbKi, 1.0_DbKi, -100.0_DbKi , 100.0_DbKi ,LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI) ! NJA: should never reach saturation limits....
! Mod made by A. Wright: use the gain scheduled value of KPfloat in the floating fb equ's below (instead of the old value of CntrPar%Fl_Kp), for either value of CntrPar%Fl_Mode...
        if (CntrPar%Fl_Mode == 1) THEN
            FloatingFeedback = (0.0_DbKi - FA_vel) * LocalVar%Kp_Float ! Mod made by A. Wright: use the gain scheduled value of KPfloat in the floating fb equ's below (instead of the old value of CntrPar%Fl_Kp), for either value of CntrPar%Fl_Mode...
        ELSEIF (CntrPar%Fl_Mode == 2) THEN
            FloatingFeedback = (0.0_DbKi - NacIMU_FA_vel) *LocalVar%Kp_Float ! Mod made by A. Wright: use the gain scheduled value of KPfloat in the floating fb equ's below (instead of the old value of CntrPar%Fl_Kp), for either value of CntrPar%Fl_Mode...
        END IF

    END FUNCTION FloatingFeedback
!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE FlapControl(avrSWAP, CntrPar, LocalVar, objInst)
        ! Yaw rate controller
        !       Y_ControlMode = 0, No yaw control
        !       Y_ControlMode = 1, Simple yaw rate control using yaw drive
        !       Y_ControlMode = 2, Yaw by IPC (accounted for in IPC subroutine)
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances

        REAL(ReKi), INTENT(INOUT) :: avrSWAP(*) ! The swap array, used to pass data to, and receive data from, the DLL controller.

        TYPE(ControlParameters), INTENT(INOUT)    :: CntrPar
        TYPE(LocalVariables), INTENT(INOUT)       :: LocalVar
        TYPE(ObjectInstances), INTENT(INOUT)      :: objInst
        ! Internal Variables
        INTEGER(IntKi)              :: K
        REAL(DbKi)                  :: RootMyb_Vel(3)
        REAL(DbKi)                  :: RootMyb_VelErr(3)
        REAL(DbKi)                  :: axisTilt_1P, axisYaw_1P    ! Direct axis and quadrature axis outputted by Coleman transform, 1P
        REAL(DbKi)                  :: Flp_axisTilt_1P, Flp_axisYaw_1P ! Flap command in direct and quadrature axis coordinates
        ! Flap control
        IF (CntrPar%Flp_Mode > 0) THEN
            IF (LocalVar%iStatus == 0) THEN
                LocalVar%RootMyb_Last(1) = 0 - LocalVar%rootMOOP(1)
                LocalVar%RootMyb_Last(2) = 0 - LocalVar%rootMOOP(2)
                LocalVar%RootMyb_Last(3) = 0 - LocalVar%rootMOOP(3)
                ! Initial Flap angle
                LocalVar%Flp_Angle(1) = CntrPar%Flp_Angle
                LocalVar%Flp_Angle(2) = CntrPar%Flp_Angle
                LocalVar%Flp_Angle(3) = CntrPar%Flp_Angle
                ! Initialize controller
                IF (CntrPar%Flp_Mode == 2) THEN
                    LocalVar%Flp_Angle(K) = PIIController(RootMyb_VelErr(K), 0 - LocalVar%Flp_Angle(K), CntrPar%Flp_Kp, CntrPar%Flp_Ki, 0.05_DbKi, -CntrPar%Flp_MaxPit , CntrPar%Flp_MaxPit , LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
                ENDIF

            ! Steady flap angle
            ELSEIF (CntrPar%Flp_Mode == 1) THEN
                LocalVar%Flp_Angle(1) = LocalVar%Flp_Angle(1)
                LocalVar%Flp_Angle(2) = LocalVar%Flp_Angle(2)
                LocalVar%Flp_Angle(3) = LocalVar%Flp_Angle(3)

            ! PII flap control
            ELSEIF (CntrPar%Flp_Mode == 2) THEN
                DO K = 1,LocalVar%NumBl
                    ! Find flap angle command - includes an integral term to encourage zero flap angle
                    LocalVar%Flp_Angle(K) = PIIController(-LocalVar%rootMOOPF(K), 0 - LocalVar%Flp_Angle(K), CntrPar%Flp_Kp, CntrPar%Flp_Ki, 0.05_DbKi, -CntrPar%Flp_MaxPit , CntrPar%Flp_MaxPit , LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
                    ! Saturation Limits
                    LocalVar%Flp_Angle(K) = saturate(LocalVar%Flp_Angle(K), -CntrPar%Flp_MaxPit, CntrPar%Flp_MaxPit) * R2D
                END DO

            ! Cyclic flap Control
            ELSEIF (CntrPar%Flp_Mode == 3) THEN
                ! Pass rootMOOPs through the Coleman transform to get the tilt and yaw moment axis
                CALL ColemanTransform(LocalVar%rootMOOPF, LocalVar%Azimuth, NP_1, axisTilt_1P, axisYaw_1P)

                ! Apply PI control
                Flp_axisTilt_1P = PIController(axisTilt_1P, CntrPar%Flp_Kp, CntrPar%Flp_Ki, -CntrPar%Flp_MaxPit, CntrPar%Flp_MaxPit, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)
                Flp_axisYaw_1P = PIController(axisYaw_1P, CntrPar%Flp_Kp, CntrPar%Flp_Ki, -CntrPar%Flp_MaxPit, CntrPar%Flp_MaxPit, LocalVar%DT, 0.0_DbKi, LocalVar%piP, LocalVar%restart, objInst%instPI)

                ! Pass direct and quadrature axis through the inverse Coleman transform to get the commanded pitch angles
                CALL ColemanTransformInverse(Flp_axisTilt_1P, Flp_axisYaw_1P, LocalVar%Azimuth, NP_1, 0.0_DbKi, LocalVar%Flp_Angle)

            ENDIF

            ! Send to AVRSwap
            avrSWAP(120) = LocalVar%Flp_Angle(1)   ! Send flap pitch command (deg)
            avrSWAP(121) = LocalVar%Flp_Angle(2)   ! Send flap pitch command (deg)
            avrSWAP(122) = LocalVar%Flp_Angle(3)   ! Send flap pitch command (deg)
        ELSE
            RETURN
        ENDIF
    END SUBROUTINE FlapControl


!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE ActiveWakeControl(CntrPar, LocalVar, DebugVar)
        ! Active wake controller
        !       AWC_Mode = 0, No active wake control
        !       AWC_Mode = 1, SNL active wake control
        !       AWC_Mode = 2, Coleman Transform-based active wake control
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, DebugVariables, ObjectInstances

        TYPE(ControlParameters), INTENT(INOUT)    :: CntrPar
        TYPE(DebugVariables), INTENT(INOUT)       :: DebugVar
        TYPE(LocalVariables), INTENT(INOUT)       :: LocalVar

        ! Local vars
        REAL(DbKi), PARAMETER      :: phi1 = 0.0                       ! Phase difference from first to first blade
        REAL(DbKi), PARAMETER      :: phi2 = 2.0/3.0*PI                ! Phase difference from first to second blade
        REAL(DbKi), PARAMETER      :: phi3 = 4.0/3.0*PI                ! Phase difference from first to third blade
        REAL(DbKi), DIMENSION(3)                        :: AWC_angle
        COMPLEX(DbKi), DIMENSION(3)                    :: AWC_complexangle
        COMPLEX(DbKi)                                  :: complexI = (0.0, 1.0)
        INTEGER(IntKi)                                  :: Imode, K       ! Index used for looping through AWC modes, blades
        REAL(DbKi)                 :: clockang                         ! Clock angle for AWC pitching
        REAL(DbKi)                 :: omega                            ! angular frequency for AWC pitching in Hz
        REAL(DbKi)                 :: amp                              ! amplitude for AWC pitching in degrees
        REAL(DbKi), DIMENSION(2)   :: AWC_TiltYaw = [0.0, 0.0]         ! AWC Tilt and yaw pitch signal


        ! Compute the AWC pitch settings
        IF (CntrPar%AWC_Mode == 1) THEN

            LocalVar%AWC_complexangle = 0.0D0

            DO Imode = 1,CntrPar%AWC_NumModes
                clockang = CntrPar%AWC_clockangle(Imode)*PI/180.0_DbKi
                omega = CntrPar%AWC_freq(Imode)*PI*2.0_DbKi
                AWC_angle(1) = omega * LocalVar%Time - CntrPar%AWC_n(Imode) * (LocalVar%Azimuth + phi1 + clockang)
                AWC_angle(2) = omega * LocalVar%Time - CntrPar%AWC_n(Imode) * (LocalVar%Azimuth + phi2 + clockang)
                AWC_angle(3) = omega * LocalVar%Time - CntrPar%AWC_n(Imode) * (LocalVar%Azimuth + phi3 + clockang)
                ! Add the forcing contribution to LocalVar%AWC_complexangle
                amp = CntrPar%AWC_amp(Imode)*PI/180.0_DbKi
                DO K = 1,LocalVar%NumBl ! Loop through all blades
                    LocalVar%AWC_complexangle(K) = LocalVar%AWC_complexangle(K) + amp * EXP(complexI * (AWC_angle(K)))
                END DO
            END DO

            DO K = 1,LocalVar%NumBl ! Loop through all blades, apply AWC_angle
                LocalVar%PitCom(K) = LocalVar%PitCom(K) + REAL(LocalVar%AWC_complexangle(K))
            END DO

        ELSEIF (CntrPar%AWC_Mode == 2) THEN

            DO Imode = 1,CntrPar%AWC_NumModes
                DebugVar%axisTilt_1P = AWC_TiltYaw(1)
                AWC_TiltYaw = [0.0, 0.0]
                AWC_TiltYaw(Imode) = PI/180*CntrPar%AWC_amp(Imode)*cos(LocalVar%Time*2*PI*CntrPar%AWC_freq(Imode) + CntrPar%AWC_clockangle(Imode)*PI/180)
                IF (CntrPar%AWC_NumModes == 1) THEN
                    AWC_TiltYaw(2) = PI/180*CntrPar%AWC_amp(1)*cos(LocalVar%Time*2*PI*CntrPar%AWC_freq(1) + 2*CntrPar%AWC_clockangle(1)*PI/180)
                ENDIF
                CALL ColemanTransformInverse(AWC_TiltYaw(1), AWC_TiltYaw(2), LocalVar%Azimuth, CntrPar%AWC_harmonic(Imode), REAL(0.0,DbKi), AWC_angle)

                DO K = 1,LocalVar%NumBl ! Loop through all blades, apply AWC_angle
                    LocalVar%PitCom(K) = LocalVar%PitCom(K) + AWC_angle(K)
                END DO
            END DO
            DebugVar%axisYaw_1P = AWC_TiltYaw(2)
            DebugVar%axisTilt_2P = AWC_angle(1)

        ENDIF

    END SUBROUTINE ActiveWakeControl

!-------------------------------------------------------------------------------------------------------------------------------
    SUBROUTINE CableControl(avrSWAP, CntrPar, LocalVar, objInst, ErrVar)
        ! Cable controller
        !       CC_Mode = 0, No cable control, this code not executed
        !       CC_Mode = 1, User-defined cable control
        !       CC_Mode = 2, Position control, not yet implemented
        !
        ! Note that LocalVar%CC_Actuated*(), and CC_Desired() has a fixed max size of 12, which can be increased in rosco_types.yaml
        !
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances, ErrorVariables

        REAL(ReKi), INTENT(INOUT) :: avrSWAP(*) ! The swap array, used to pass data to, and receive data from, the DLL controller.

        TYPE(ControlParameters), INTENT(INOUT)    :: CntrPar
        TYPE(LocalVariables), INTENT(INOUT)       :: LocalVar
        TYPE(ObjectInstances), INTENT(INOUT)      :: objInst
        TYPE(ErrorVariables), INTENT(INOUT)      :: ErrVar

        ! Internal Variables
        Integer(IntKi)                            :: I_GROUP
        CHARACTER(*),               PARAMETER           :: RoutineName = 'StructuralControl'



        IF (CntrPar%CC_Mode == 1) THEN
            ! User defined control

            IF (LocalVar%Time > 500) THEN
                ! Shorten first group by 4 m
                LocalVar%CC_DesiredL(1) = -14.51
                LocalVar%CC_DesiredL(2) = 1.58
                LocalVar%CC_DesiredL(3) = -10.332


            END IF

        ELSEIF (CntrPar%CC_Mode == 2) THEN
            ! Open loop control
            ! DO I_GROUP = 1, CntrPar%CC_Group_N
            !     LocalVar%CC_DesiredL(I_GROUP) = interp1d(x,y,eq,ErrVar)

            DO I_GROUP = 1,CntrPar%CC_Group_N
                IF (CntrPar%Ind_CableControl(I_GROUP) > 0) THEN
                    LocalVar%CC_DesiredL(I_GROUP) = interp1d(CntrPar%OL_Breakpoints, &
                                                            CntrPar%OL_CableControl(I_GROUP,:), &
                                                            LocalVar%Time,ErrVar)
                ENDIF
            ENDDO



        END IF

        ! Convert desired to actuated line length and delta length for all groups

        DO I_GROUP = 1, CntrPar%CC_Group_N

            ! Get Actuated deltaL
            LocalVar%CC_ActuatedDL(I_GROUP) = SecLPFilter_Vel(LocalVar%CC_DesiredL(I_GROUP),LocalVar%DT,2*PI/CntrPar%CC_ActTau,REAL(1.0,DbKi), &
                                                                LocalVar%FP,LocalVar%iStatus,LocalVar%restart,objInst%instSecLPFV)

            ! Integrate
            LocalVar%CC_ActuatedL(I_GROUP) = PIController(LocalVar%CC_ActuatedDL(I_GROUP),0.0_DbKi,1.0_DbKi, &
                                                    -1000.0_DbKi,1000.0_DbKi,LocalVar%DT,LocalVar%CC_ActuatedDL(1), &
                                                    LocalVar%piP, LocalVar%restart, objInst%instPI)

        END DO

        ! Assign to avrSWAP
        DO I_GROUP = 1, CntrPar%CC_Group_N

            avrSWAP(CntrPar%CC_GroupIndex(I_GROUP)) = LocalVar%CC_ActuatedL(I_GROUP)
            avrSWAP(CntrPar%CC_GroupIndex(I_GROUP)+1) = LocalVar%CC_ActuatedDL(I_GROUP)

        END DO

        ! Add RoutineName to error message
        IF (ErrVar%aviFAIL < 0) THEN
            ErrVar%ErrMsg = RoutineName//':'//TRIM(ErrVar%ErrMsg)
        ENDIF

    END SUBROUTINE CableControl

!-------------------------------------------------------------------------------------------------------------------------------
SUBROUTINE StructuralControl(avrSWAP, CntrPar, LocalVar, objInst, ErrVar)
        ! Cable controller
        !       StC_Mode = 0, No cable control, this code not executed
        !       StC_Mode = 1, User-defined cable control
        !       StC_Mode = 2, Ballast-like control, not yet implemented
        !
        ! Note that LocalVar%StC_Input() has a fixed max size of 12, which can be increased in rosco_types.yaml
        !
        USE ROSCO_Types, ONLY : ControlParameters, LocalVariables, ObjectInstances, ErrorVariables

        REAL(ReKi), INTENT(INOUT) :: avrSWAP(*) ! The swap array, used to pass data to, and receive data from, the DLL controller.

        TYPE(ControlParameters), INTENT(INOUT)    :: CntrPar
        TYPE(LocalVariables), INTENT(INOUT)       :: LocalVar
        TYPE(ObjectInstances), INTENT(INOUT)      :: objInst
        TYPE(ErrorVariables), INTENT(INOUT)      :: ErrVar


        ! Internal Variables
        Integer(IntKi)                            :: I_GROUP
        CHARACTER(*),               PARAMETER           :: RoutineName = 'StructuralControl'



        IF (CntrPar%StC_Mode == 1) THEN
            ! User defined control, step example

            IF (LocalVar%Time > 500) THEN
                ! Step change in input of -4500 N
                LocalVar%StC_Input(1) = -1.234e+06
                LocalVar%StC_Input(2) = 2.053e+06
                LocalVar%StC_Input(3) = -7.795e+05

            END IF


        ELSEIF (CntrPar%StC_Mode == 2) THEN


            DO I_GROUP = 1,CntrPar%StC_Group_N
                IF (CntrPar%Ind_StructControl(I_GROUP) > 0) THEN
                    LocalVar%StC_Input(I_GROUP) =  interp1d(CntrPar%OL_Breakpoints, &
                                                            CntrPar%OL_StructControl(I_GROUP,:), &
                                                            LocalVar%Time,ErrVar)
                ENDIF
            ENDDO



        END IF


        ! Assign to avrSWAP
        DO I_GROUP = 1, CntrPar%StC_Group_N
            avrSWAP(CntrPar%StC_GroupIndex(I_GROUP)) = LocalVar%StC_Input(I_GROUP)
        END DO

        ! Add RoutineName to error message
        IF (ErrVar%aviFAIL < 0) THEN
            ErrVar%ErrMsg = RoutineName//':'//TRIM(ErrVar%ErrMsg)
        ENDIF

    END SUBROUTINE StructuralControl
!-------------------------------------------------------------------------------------------------------------------------------
END MODULE Controllers
