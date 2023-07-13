# 1D-SIM
1D McGill Sea Ice Model 

This is a very simple 1D VP sea ice model.  

  
Define experiments and set parameters in ice.f90.  
You can output results by setting the time level in out_step.  
For example, with Deltat=3600, out_step(1)=24 means that the fields will be saved in the output directory after 1 day.  
You can have other outputs saved with out_step(2), out_step(3)...  

For setup and compilation just run the compile_script.ksh. If it does not work, just do:  
make  
make  
mkdir output  

To launch the simulation, type ./zoupa 
