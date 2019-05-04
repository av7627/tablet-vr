 %delete all 'test' log files in TrialBased log folder
recycle on; %send files to recycle bin

Foldername = 'C:\Users\Gandhi Lab.DESKTOP-IQP0LND\Documents\VR_TrialBased';

listing = dir(Foldername);

[r, inx]=sort({listing.date});
list = listing(inx);

 for i = 1:numel(listing) %this loop deletes test files 
  fn =  strcat(Foldername,'\',listing(i).name);
  
  try
      MouseName = listing(i).name(1:4);
  catch
      MouseName = 'xxxxx';
  end
  
  if strcmp('test', MouseName ) %test file
    delete(fn)
%   rmdir(fn)
  end
  
 end
 
 for i = 1:numel(listing) %this loop deletes .mat files
  fn =  strcat(Foldername,'\',listing(i).name)
  
    try
      filetype = listing(i).name(end-3:end) %.mat or .csv
    catch
      filetype = 'xxxx'
    end
      
  
  if strcmp('.mat', filetype) %.mat files
    delete(fn)
    
  end
  
 end

 
  




