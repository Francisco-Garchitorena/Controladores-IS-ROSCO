""" 
Versión que no busca calcular el daño. Es la que usé inicialmente, para sacar LWT DEL y AEP.
- Get results for a single simulation
- Open and OpenFAST binary file
- Convert it to a pandas dataframe
- Compute damage equivalent load for a given Wohler exponent
"""
import sys
sys.path.append('D:/Usuarios/fgarchitorena/OpenFast/openfast_toolbox-main')
import os
import numpy as np
import matplotlib.pyplot as plt
from openfast_toolbox.io import FASTOutputFile
from openfast_toolbox.tools.fatigue import equivalent_load

def getSimRes(simName, DLC_folder, var, m, Teq, bins, DLC_choice, start_index,end_index, variation, v, seeds_index, seeds=None):
    '''
    Input:
        - simName: simulation name as v7_shear0.2_TI15_d000_seed1.
        - var: Variable name whose DEL is needed. Example: TwrBsMyt_[kN-m].
        - m: Wöhler exponent.
        - Teq: The equivalent period.
        - bins: Number of bins in rainflow count histogram.
            If bins is a sequence, left edges (and the rightmost edge) of the bins.
            If bins is an int, a sequence is created dividing the range `min`--`max` of signal into `bins` number of equally sized bins.

    Output:
        - Leq: the equivalent load for given m and Teq.
        - S: ranges.
        - N: cycles.
        - bins: bin edges.
        - DELi: component 'i' of the DEL (for cycle i).
    '''

    # Read an openFAST binary
    sim = simName.split('_')
    baseFolder = f'E:/Usuarios/fgarchitorena/OpenFast/{DLC_folder}'
    
    if seeds is not None: #and seeds_index is not None:
        # Ensure seeds_index is a string
        fastoutFilename = f'{baseFolder}/DLC_{DLC_choice[0]}/{DLC_choice}{variation}/{v}/{seeds_index}/{simName}' 
    else:
        fastoutFilename = f'{baseFolder}/DLC_{DLC_choice[0]}/{DLC_choice}{variation}/{v}/' + simName 

    print(fastoutFilename)
    
    if not os.path.exists(fastoutFilename):
        Leq = S = N = bins = DELi = T = 'No results'
        print('No results')
        return Leq, S, N, bins, DELi, T
    
    df = FASTOutputFile(fastoutFilename).toDataFrame()  #Convierte los datos del archivo de salida en un DataFrame de pandas.
    time = np.array(list(df['Time_[s]']))
    #RotPwr = np.array(list(df['RotPwr_[kW]']))
    GenPwr = np.array(list(df['GenPwr_[kW]']))
    #Mean_Rot_Pwr = np.mean(RotPwr[start_index:end_index])
    Mean_Gen_Pwr = np.mean(GenPwr[start_index:end_index])
    var_values = np.array(list(df[var]))
    max_var_value = np.max(var_values[start_index:end_index])
    #print('Potencia aerodinámica media:',Mean_Rot_Pwr )
    #print('Potencia generada media:',Mean_Gen_Pwr )
    
    #print(time[start_index])
    #print(time[end_index])
    #print(GenPwr[start_index])
    #print(GenPwr[end_index])
    
    # Compute equivalent load for one signal and Wohler slope
#    return equivalent_load(df['Time_[s]'][start_index:end_index], df[var][start_index:end_index], m=m, Teq=Teq, bins=bins, method='rainflow_windap',
#            meanBin=True, binStartAt0=False,
#            outputMore=True, debug=False)
    #return equivalent_load(df['Time_[s]'][start_index:end_index], df[var][start_index:end_index], Teq=Teq, m=m,outputMore=True, bins=bins)#, method='rainflow_windap',
          #  meanBin=True, binStartAt0=False,
           # , debug=False)
    # Return Mean_Gen_Pwr only if DLC_choice is '1p2', otherwise return None
    if DLC_choice == '1p2' or '1p1':
        return equivalent_load(df['Time_[s]'][start_index:end_index], df[var][start_index:end_index], m=m, Teq=Teq, bins=bins, outputMore=True), Mean_Gen_Pwr, max_var_value
    else:
        return equivalent_load(df['Time_[s]'][start_index:end_index], df[var][start_index:end_index], Teq=Teq, m=m, outputMore=True, bins=bins), None,None