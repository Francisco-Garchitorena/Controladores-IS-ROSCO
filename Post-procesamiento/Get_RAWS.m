[velocity, twrVelocity, y, z, zTwr, nz, ny, dz, dy, dt, zHub, z1,mffws] = readfile_BTS('../Test_Tarnowski_OF/IEAonshore_8mps_TI5.bts');
Hubpos = [0, 0, zHub];
function [Ueff]=ComputeRotorEffective(U,Yt,Zt,Hubpos,Diam, nz, ny, nt)
    % [nt, Nx,Ny,Nz]=size(U);
    Ueff = zeros(nt,1);
    for i=1:nt
        Count = 0;
        for j=1:ny
            for k=1:nz
                Dist2rot = sqrt((Yt(j)-Hubpos(2))^2+(Zt(k)-Hubpos(3))^2);
                if Dist2rot <= Diam/2
                    Ueff(i) = Ueff(i) + U(i,1,j,k)^3;
                    Count = Count + 1;
                end
            end
        end
     
        Ueff(i) = (Ueff(i)/Count)^(1/3);
    end
end
%%
function [Ueff2]=ComputeRotorEffective2(U,Yt,Zt,Hubpos,Diam, nz, ny, nt)
    % [nt, Nx,Ny,Nz]=size(U);
    Ueff2 = zeros(nt,1);
    for i=1:nt
        Count = 0;
        for j=1:ny
            for k=1:nz
                Dist2rot = sqrt((Yt(j)-Hubpos(2))^2+(Zt(k)-Hubpos(3))^2);
                if Dist2rot <= Diam/2
                    Ueff2(i) = Ueff2(i) + U(i,1,j,k);
                    Count = Count + 1;
                end
            end
        end
     
        Ueff2(i) = (Ueff2(i)/Count);
    end
end

%%
[Ueff2]=ComputeRotorEffective2(velocity,y,z,Hubpos,130,nz,ny, 12600);
Disturbance.Ueff.time = 0:dt:12600*dt;
Disturbance.Ueff.time = Disturbance.Ueff.time(1:end-1);