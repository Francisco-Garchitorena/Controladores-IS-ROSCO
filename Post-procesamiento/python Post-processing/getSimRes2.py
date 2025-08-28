""" 
- Get results for a single simulation
- Open and OpenFAST binary file
- Convert it to a pandas dataframe
- Compute damage equivalent load for a given Wohler exponent
"""
import sys
sys.path.append('C:/Users/fgarchitorena/OpenFast/Design Load Cases/openfast_toolbox-main')
import os
import numpy as np
import matplotlib.pyplot as plt
from openfast_toolbox.io import FASTOutputFile
from openfast_toolbox.tools.fatigue import equivalent_load

def getSimRes2(simName, var, m, Teq, bins, start_index,end_index):
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
    # sim = simName.split('_')
    # baseFolder = f'E:/Usuarios/fgarchitorena/OpenFast/{DLC_folder}'
    
    # if seeds is not None: #and seeds_index is not None:
    #     # Ensure seeds_index is a string
    #     fastoutFilename = f'{baseFolder}/DLC_{DLC_choice[0]}/{DLC_choice}{variation}/{v}/{seeds_index}/{simName}' 
    # else:
    #     fastoutFilename = f'{baseFolder}/DLC_{DLC_choice[0]}/{DLC_choice}{variation}/{v}/' + simName 

   # print(fastoutFilename)
    
    if not os.path.exists(simName):
        Leq = S = N = bins = DELi = T = 'No results'
        print('No results')
        return Leq, S, N, bins, DELi, T
    
    df = FASTOutputFile(simName).toDataFrame()  #Convierte los datos del archivo de salida en un DataFrame de pandas.
    time = np.array(list(df['Time_[s]']))
    GenPwr = np.array(list(df['GenPwr_[kW]']))
    Mean_Gen_Pwr = np.mean(GenPwr[start_index:end_index])
    var_values = np.array(list(df[var]))
    max_var_value = np.max(var_values[start_index:end_index])
    
    # Return Mean_Gen_Pwr only if DLC_choice is '1p2', otherwise return None
    Leq, S, N, bins, DELi, T = equivalent_load(df['Time_[s]'][start_index:end_index], df[var][start_index:end_index], m=m, Teq=Teq, bins=bins, outputMore = True)

    return Leq, S, N, bins, DELi, T, max_var_value
