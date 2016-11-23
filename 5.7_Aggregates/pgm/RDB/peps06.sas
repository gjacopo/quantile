/*
. AROPE by most frequent activity status
*/

/* version of 18/11/2010*/
%macro UPD_peps06 (yyyy,Ucc,Uccs,flag,notBDB);

PROC DATASETS lib=work kill nolist;
QUIT;

%let cc=%lowcase(&Ucc);
%let yy=%substr(&yyyy,3,2);
%let EU=0;
%if &Uccs=0 %then %let Uccs=("&Ucc");
%else %let EU=1;

* input datasets;
/*
%if &notBDB %then %do;
	libname in "&eusilc/&cc/c&yy"; 
	%let infil=c&cc&yy;
	%end;
%else %do;
	libname in "&eusilc/BDB"; 
	%let infil=BDB_c&yy;
	%end;
*/
%let not60=0;

%if &EU=0 %then %do;

PROC FORMAT; /* change the age codes with new ones and proper for that table*/
VALUE f_age (multilabel)

		18 - HIGH = "Y_GE18"
		18 - 64 = "Y18-64"
		20 - 64 = "Y20-64"
		65 - HIGH = "Y_GE65"
		18 - 59 = "Y18-59"
		60 - HIGH = "Y_GE60"
		18 - 54 = "Y18-54"
		25 - 59 = "Y25-59"
		25 - 54 = "Y25-54"
		55 - HIGH = "Y_GE55";

VALUE f_sex (multilabel)
		1 = "M"
		2 = "F"
		1 - 2 = "T";


VALUE f_C_BIRTH (multilabel)
		1 = "NAT"
		3 = "EU27_FOR"
		2 = "NEU27_FOR"
		6 = "EU28_FOR"
		4 = "NEU28_FOR"
		2 - 6 = "FOR" ;
		

VALUE $f_AROPE (multilabel)
	"000" ="0"
	OTHER = "1";

RUN;


* extract from IDB;

PROC SQL noprint;
Create table work.idb as 
	select distinct DB010, DB020, RB030, RB050a, Age, RB090, AROPE, C_BIRTH
	from idb.IDB&yy as IDB
	where DB020 in &Uccs and age ge 18;
QUIT;

* calculate % missing values;

PROC SQL noprint;

CREATE TABLE nfilled AS SELECT DISTINCT DB020, (N(RB030)) AS N1 FROM work.idb WHERE AGE not is missing GROUP BY DB020;
CREATE TABLE nmissing AS SELECT DISTINCT DB020, (N(RB030)) AS N_1 FROM work.idb WHERE AGE is missing GROUP BY DB020;
CREATE TABLE mAGE AS SELECT nfilled.DB020, (100/(N1+N_1)*N_1) AS mAGE FROM nfilled LEFT JOIN nmissing ON (nfilled.DB020 = nmissing.DB020);

CREATE TABLE nfilled AS SELECT DISTINCT DB020, (N(RB030)) AS N1 FROM work.idb WHERE RB090 not is missing GROUP BY DB020;
CREATE TABLE nmissing AS SELECT DISTINCT DB020, (N(RB030)) AS N_1 FROM work.idb WHERE RB090 is missing GROUP BY DB020;
CREATE TABLE mRB090 AS SELECT nfilled.DB020, (100/(N1+N_1)*N_1) AS mRB090 FROM nfilled LEFT JOIN nmissing ON (nfilled.DB020 = nmissing.DB020);

CREATE TABLE nfilled AS SELECT DISTINCT DB020, (N(RB030)) AS N1 FROM work.idb WHERE AROPE not is missing GROUP BY DB020;
CREATE TABLE nmissing AS SELECT DISTINCT DB020, (N(RB030)) AS N_1 FROM work.idb WHERE AROPE is missing GROUP BY DB020;
CREATE TABLE mAROPE AS SELECT nfilled.DB020, (100/(N1+N_1)*N_1) AS mAROPE FROM nfilled LEFT JOIN nmissing ON (nfilled.DB020 = nmissing.DB020);

CREATE TABLE nfilled AS SELECT DISTINCT DB020, (N(RB030)) AS N1 FROM work.idb WHERE C_BIRTH not is missing GROUP BY DB020;
CREATE TABLE nmissing AS SELECT DISTINCT DB020, (N(RB030)) AS N_1 FROM work.idb WHERE C_BIRTH is missing GROUP BY DB020;
CREATE TABLE mC_BIRTH AS SELECT nfilled.DB020, (100/(N1+N_1)*N_1) AS mC_BIRTH FROM nfilled LEFT JOIN nmissing ON (nfilled.DB020 = nmissing.DB020);

CREATE TABLE missunrel AS SELECT mAGE.DB020, 
	max(mAGE, mRB090, mAROPE, mC_BIRTH) AS pcmiss
	FROM mAGE 
	LEFT JOIN mRB090 ON (mAGE.DB020 = mRB090.DB020)
	LEFT JOIN mAROPE ON (mAGE.DB020 = mAROPE.DB020)
	LEFT JOIN mC_BIRTH ON (mAGE.DB020 = mC_BIRTH.DB020);
QUIT;

* calc values, N and total weights;

PROC TABULATE data=work.idb out=Ti;

		FORMAT AGE f_age15.;
		FORMAT RB090 f_sex.;
		FORMAT AROPE $f_AROPE.;
		FORMAT C_BIRTH f_C_BIRTH15.;
		
		CLASS AGE /MLF;
		CLASS RB090 /MLF;
		CLASS C_BIRTH /MLF;
		CLASS AROPE /MLF;
		CLASS DB020;
	VAR RB050a;

	TABLE DB020 * AGE * RB090 * C_BIRTH, AROPE * RB050a * (RowPctSum N Sum) /printmiss;

RUN;



* fill RDB variables;
%macro by_unit(unit,ival); 

PROC SQL;

CREATE TABLE work.old_flag AS SELECT
	geo,
	time, 
	age,
	sex,
	c_birth,
	unit,
	ivalue,
	iflag
FROM rdb.peps06
WHERE geo in &Uccs and unit ="&unit" and time = &yyyy;

CREATE TABLE work.peps06 AS
SELECT 
	Ti.DB020 as geo FORMAT=$5. LENGTH=5,
	&yyyy as time,
	Ti.Age,
	Ti.RB090 as sex,
	Ti.AROPE,
	Ti.C_BIRTH as c_birth,
	"&unit" as unit,
	Ti.&ival as ivalue,
	/*old_flag.iflag*/ "" as iflag,
	(case when sum(Ti.RB050a_N) < 20 or missunrel.pcmiss > 50 then 2
		  when sum(Ti.RB050a_N) < 50 or missunrel.pcmiss > 20 then 1
		  else 0
	      end) as unrel,
	Ti.RB050a_N as n,
	sum(Ti.RB050a_N) as ntot,
	sum(Ti.RB050a_Sum) as totwgh,
	"&sysdate" as lastup,
	"&sysuserid" as	lastuser 
FROM Ti LEFT JOIN missunrel ON (Ti.DB020 = missunrel.DB020)
	LEFT JOIN work.old_flag ON (Ti.DB020=old_flag.geo) AND (Ti.Age=old_flag.age) AND ( Ti.RB090 = old_flag.sex) AND (Ti.C_BIRTH=old_flag.c_birth)
GROUP BY Ti.DB020, ti.AGE, ti.RB090, ti.C_BIRTH
ORDER BY Ti.DB020, ti.AGE, ti.RB090, ti.C_BIRTH;
QUIT;

* Update RDB;
DATA  rdb.peps06 (drop= AROPE);
set rdb.peps06(where=(not(time = &yyyy and geo = "&Ucc" and unit = "&unit")))
    work.peps06;
	where AROPE="1";
RUN;
%mend by_unit;

	%by_unit(PC_POP,RB050a_PctSum_11101);
	*%by_unit(THS_PER,RB050a_Sum/1000);


%end;

%if &EU %then %do;

* EU aggregates;

%let tab=peps06;
%let grpdim=age, sex, c_birth, unit;
%EUVALS(&Ucc,&Uccs);

%end;

PROC SQL;  
     Insert into log.log
     set date = "&sysdate"d, time = "&systime"t, user = "&sysuserid",
		 report = "* &Ucc - &yyyy * peps06 (re)calculated *";		  
QUIT;

%mend UPD_peps06;
