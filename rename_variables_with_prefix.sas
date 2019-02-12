* this macro renames all variables in a dataset with a prefix;

%macro vars(dsn,chr,out);                                                                                                               
   %let dsid=%sysfunc(open(&dsn));                                                                                                        
   %let n=%sysfunc(attrn(&dsid,nvars));                                                                                                 
   data &out;                                                                                                                            
      set &dsn(rename=(                                                                                                                    
      %do i = 1 %to &n;                                                                                                                 
         %let var=%sysfunc(varname(&dsid,&i));                                                                                            
         &var=&chr&var                                                                                                              
      %end;));                                                                                                                            
      %let rc=%sysfunc(close(&dsid));                                                                                                        
   run;                                                                                                                                  
%mend vars;                                                                                                                             
                                                                                                                                        
/** First parameter is the data set that contains all of the variables.  **/
/** Second parameter is the characters used for the prefix.              **/
/** Third parameter is the new data set that contains the new variables. **/  