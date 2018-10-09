****************************************************************************************************;
/* 
 * This macro creates Table 1. Descriptive Statistics. All dataset cleaning should be performed prior
 * to running this macro. Required inputs are: 
 * 	dataset = name of dataset
 * 	col_var = name of categorical variable presented in columns of table (often primary exposure)
 * 	col_fmt = format name for col_var. THIS MUST BE INCLUDED, AND MUST BE A CHARACTER FORMAT.
 * 	cat_vars = list of categorical variables, separated by spaces
 * 	cont_vars = list of continuous variables, separated by spaces
 * Table 1 will be shown at the bottom of the output, and a dataset named "table_1" will be created.
 * Categorical variables are presented as frequency (percent%). Chi square p values are calculated.
 * Continuous variables are presented as mean (sd). Two way ANOVA p values are calculated. 
 */
****************************************************************************************************;
* Declare library/dataset here:;

* Include a proc format statement with the format of the column variable here:; 

/* Declare variables here:;
%let dataset = ; * Name of dataset;
%let col_var = ; * Column vairable;
%let col_fmt = ; * Format used for column variable - must be a character format;
%let cat_vars = ; * Categorical variables separated by spaces;
%let cont_vars = ; * Continuous variables separated by spaces;
*/
****************************************************************************************************;
* DO NOT CHANGE ANYTHING BELOW THIS LINE ***********************************************************;
* 
* separate dataset into columns and total -- uses iteration variable "i";
%macro columns(dataset, col_var, col_fmt);
	* count number of categories in the columns variable;
	ods output OneWayFreqs=col_freq; proc freq data=&dataset; tables &col_var; format &col_var &col_fmt..; run; ods output close;
	data col_freq; set col_freq; col_counter = _n_; run;
	proc print data=col_freq; format &col_var; run;
	%global g_col_count; * global column count variable;
	proc sql noprint; select count(&col_var) into :col_count from col_freq; quit;
	%let g_col_count = &col_count; * store column count to a global variable;
	%put number of columns is: &g_col_count;
	* store column names to memory;
	%do i=1 %to &g_col_count; %global col_&i; %put col_&i; %end; * make the names global;
	proc sql noprint; select f_&col_var into :col_1 - :col_%left(&col_count) from col_freq; quit;
	* create datasets for each category;
	proc sort data=&dataset; by &col_var; run;
	%do i=1 %to &g_col_count;
		data col_&i; 
			merge &dataset col_freq (in=a);
			by &col_var;
			if col_counter = &i then output;
		run;
		proc print data=col_&i (obs=5); run;
	%end;
%mend columns;

* create continuous variable line;
%macro mean_sd(dataset, cont_vars);
	%put continuous variables: &cont_vars;
	ods output BasicMeasures=basic_out; proc univariate data=&dataset; *histogram; var &cont_vars; run; ods output close;
	proc print data=basic_out; run;
	data basic_out; length VarName $32.; set basic_out; * create dataset with mean and standard deviation;
		format LocValue f12.2 VarValue f12.2;
		if LocMeasure ^= "Mean" then delete;
		&dataset = catt(round(LocValue, 0.01), " (", round(VarValue, 0.01), ")"); * format "mean (SD)";
		keep VarName &dataset;
	run;
	proc print data=basic_out; run;
%mend mean_sd;

* create categorical variable line;
%macro freq_percent(dataset, cat_vars);
	%put categorical variables: &cat_vars;
	ods output OneWayFreqs = freq_out; proc freq data=&dataset; tables &cat_vars; run; ods output close;
	proc print data=freq_out; run;
	data freq_out; length VarName $32.; set freq_out; 
		format Percent f12.2;
		VarName=scan(table,-1);
		Category=vvaluex('F_'||VarName);
		&dataset = catt(Frequency, " (", round(Percent, 0.01), "%)"); * format n "(percent%)";
		keep VarName Category &dataset;
	run;
	proc print data=freq_out; run;
%mend freq_percent;

* create column with both categorical and continuous results;
%macro create_column(dataset, cat_vars, cont_vars);
	%freq_percent(&dataset, &cat_vars); * create frequency (percent) for whole dataset;
	%mean_sd(&dataset, &cont_vars); * create mean (sd) for whole dataset;
	data &dataset._out; length VarName $32.; set freq_out basic_out; run; * stack two datasets with frequency (percent) and mean (sd) from the whole dataset;
	proc print data=&dataset._out; run;
%mend create_column;

*%create_column(total, sex diabetes_yu education smoking drinking CKD_GFR_Based, age bmi avesbp glucose physical_activity egfr_ckd_epi);

* extract variable labels;
%macro var_labels(dataset);
	ods output Variables=var_labels; proc contents data=&dataset; run; ods output close;
	proc print data=var_labels; run;
	data var_labels; set var_labels;
		keep Variable Label;
		rename Variable = VarName;
	run;
	proc print data=var_labels; run;
%mend var_labels;

* count n for each varaible - both categorical and continuous;
%macro count_n(dataset, cat_vars, cont_vars);
	ods output Moments=moments_out; proc univariate data=&dataset; var &cat_vars &cont_vars; run; ods output close;
	data row_titles_and_ns; length VarName $32.; set moments_out;
		if Label1 ^= "N" then delete;
		rename cValue1 = n;
		order = _n_;
		keep VarName cValue1 order;
	run;
	proc print data=row_titles_and_ns; run;
%mend count_n;

* p value categorical - chi square p value;
%macro p_cat(dataset, col_var, cat_vars);
	ods output ChiSq=chisq_out; proc freq data=&dataset; tables &col_var*(&cat_vars)/chisq; run; ods output close;
	proc print data=chisq_out; run;
	data p_cat; length VarName $32.;set chisq_out;
		if Statistic ^= "Chi-Square" then delete;
		VarName=scan(table,-1); * rename table to just include the row var;
		rename Prob=P;
		keep VarName Prob;
		******* format p value;
	run;
	proc print data=p_cat; run;
%mend p_cat;

* p value continuous - ANOVA p value -- uses iteration variable "j";
%macro p_cont(dataset, col_var, cont_vars);
	%let word_count=%sysfunc(countw(&cont_vars));
	%put There are &word_count words in the string "&cont_vars";
	%do j=1 %to &word_count;
		%let current_var=%scan(&cont_vars, &j);
		%put current variable: &current_var;
		ods output ModelANOVA=anova_out_&j; proc anova plots=none data=&dataset; class &col_var; model &current_var = &col_var; run; quit; ods output close;
		proc print data=anova_out_&j; run;
		data anova_out_&j; set anova_out_&j; 
			rename Dependent=VarName ProbF = P;
			keep Dependent ProbF;
		run;
		proc print data=anova_out_&j; run;
	%end;
	* stack anova p value tables;
	data p_cont; length VarName $32.; set anova_:; run;
	******* format p value;
	proc print data=p_cont; run;
%mend p_cont;
	
* stack lines -- uses iteration variable "k"; 
%macro build_table(dataset, col_var, cat_vars, cont_vars, col_fmt);
	%put dataset: &dataset; %put col_var: &col_var; %put cat_vars: &cat_vars; %put cont_vars: &cont_vars;
	%columns(&dataset, &col_var, &col_fmt); * create datasets for each column and global variables for number of datasets and column names;
	* create datasets;
	%count_n(&dataset, &cat_vars, &cont_vars); * row titles and ns;
	%var_labels(&dataset); * variable labels;
	%p_cat(&dataset, &col_var, &cat_vars);* create categorical p value dataset;
	%p_cont(&dataset, &col_var, &cont_vars);* create continuous p value dataset;
	data p_values; set p_cat p_cont; run; * stack two datasets with p values;
	%create_column(&dataset, &cat_vars, &cont_vars);* stack datasets with output from total dataset;
	* create subset column datasets;
	%do k=1 %to &g_col_count; 
		%put &k: &&col_&k; 
		%create_column(col_&k, &cat_vars, &cont_vars);
		data column_&k; set col_&k._out; rename col_&k = &&col_&k; run;
		proc print data=column_&k; run;
		proc sort data=column_&k; by VarName Category; run;
	%end;
	* merge general info;
	proc sort data=row_titles_and_ns; by VarName; run;
	proc sort data=var_labels; by VarName; run;
	proc sort data=&dataset._out; by VarName; run;
	proc sort data=p_values; by VarName; run;
	data table_1_general;
		merge row_titles_and_ns (in=a) var_labels &dataset._out p_values;
		by VarName;
		if a=1 then output;
	run;
	* merge subset column datasets with general info;
	proc sort data=table_1_general; by VarName Category; run;
	data table_1;
		merge table_1_general column_:;
		by VarName Category;
	run;
	* clean table;
	proc print data=table_1; run;
	proc sort data=table_1; by order; run;
	data table_1; set table_1 (drop=P order); set table_1 (drop=order); if VarName="&col_var" then P=.; run;
	proc print data=table_1; format P best8.; run;
	* delete temporary datasets created using this macro;
	proc datasets nolist library=work; 
		delete anova_out: basic_out chisq_out col_: column_: freq_out moments_out p_: row_titles_and_ns
				table_1_general total total_out var_labels;
	run;
%mend build_table;

****************************************************************************************************;
* run macro;
%build_table(&dataset, &col_var, &cat_vars, &cont_vars, &col_fmt);
 
