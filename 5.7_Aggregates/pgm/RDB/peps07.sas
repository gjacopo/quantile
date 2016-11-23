/*
. AROPE by tenure status
  version of 23/07/2012
*/
%macro UPD_peps07 (yyyy,Ucc,Uccs,flag,notBDB);

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

	VALUE f_tenstatu (multilabel)
			1 = "OWN_NL"
			2 = "OWN_L"
			3 = "RENT_MKT"
			4 = "RENT_FR"
			1 - 4 = "TOTAL"
			;

VALUE $f_AROPE (multilabel)
	"000" ="0"
	OTHER = "1";

RUN;


* extract from IDB;

PROC SQL noprint;
Create table work.idb as 
	select distinct DB010, DB020, RB030, RB050a, AROPE, TENSTA_2
	from idb.IDB&yy as IDB
	where DB020 in &Uccs;
QUIT;

* calculate % missing values;

PROC SQL noprint;


CREATE TABLE nfilled AS SELECT DISTINCT DB020, (N(RB030)) AS N1 FROM work.idb WHERE AROPE not is missing GROUP BY DB020;
CREATE TABLE nmissing AS SELECT DISTINCT DB020, (N(RB030)) AS N_1 FROM work.idb WHERE AROPE is missing GROUP BY DB020;
CREATE TABLE mAROPE AS SELECT nfilled.DB020, (100/(N1+N_1)*N_1) AS mAROPE FROM nfilled LEFT JOIN nmissing ON (nfilled.DB020 = nmissing.DB020);

CREATE TABLE nfilled AS SELECT DISTINCT DB020, (N(RB030)) AS N1 FROM work.idb WHERE TENSTA_2 not is missing GROUP BY DB020;
CREATE TABLE nmissing AS SELECT DISTINCT DB020, (N(RB030)) AS N_1 FROM work.idb WHERE TENSTA_2 is missing GROUP BY DB020;
CREATE TABLE mTENSTA_2 AS SELECT nfilled.DB020, (100/(N1+N_1)*N_1) AS mTENSTA_2 FROM nfilled LEFT JOIN nmissing ON (nfilled.DB020 = nmissing.DB020);

CREATE TABLE missunrel AS SELECT mAROPE.DB020,
                                 max(mAROPE, mTENSTA_2) AS pcmiss
	FROM mAROPE 
	LEFT JOIN mTENSTA_2 ON (mAROPE.DB020 = mTENSTA_2.DB020);
QUIT;

* calc values, N and total weights;

PROC TABULATE data=work.idb out=Ti;

		FORMAT AROPE $f_AROPE.;
		FORMAT TENSTA_2 f_tenstatu.;
		
		CLASS TENSTA_2 /MLF;
		CLASS AROPE /MLF;
		CLASS DB020;
	VAR RB050a;

	TABLE DB020 * TENSTA_2, AROPE * RB050a * (RowPctSum N Sum) /printmiss;

RUN;



* fill RDB variables;
%macro by_unit(unit,ival); 

PROC SQL;
CREATE TABLE work.old_flag AS SELECT
	geo,
	time, 
	tenure,
	unit,
	ivalue,
	iflag
FROM rdb.peps07
WHERE geo in &Uccs and unit ="&unit" and time = &yyyy;

CREATE TABLE work.peps07 AS
SELECT 
	Ti.DB020 as geo FORMAT=$5. LENGTH=5,
	&yyyy as time,
	Ti.AROPE,
	Ti.TENSTA_2 as tenure,
	"&unit" as unit,
	Ti.&ival as ivalue,
	old_flag.iflag as iflag,
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
	LEFT JOIN work.old_flag ON (Ti.DB020=old_flag.geo) AND (Ti.TENSTA_2=old_flag.tenure)
GROUP BY Ti.DB020, ti.TENSTA_2
ORDER BY Ti.DB020, ti.TENSTA_2;
QUIT;

* Update RDB;
DATA  rdb.peps07 (drop= AROPE);
set rdb.peps07(where=(not(time = &yyyy and geo = "&Ucc" and unit = "&unit")))
    work.peps07;
	where AROPE="1";
RUN;
%mend by_unit;

	%by_unit(PC_POP,RB050a_PctSum_101);
	*%by_unit(THS_PER,RB050a_Sum/1000);


%end;

%if &EU %then %do;

* EU aggregates;

%let tab=peps07;
%let grpdim=tenure, unit;
%EUVALS(&Ucc,&Uccs);

%end;

PROC SQL;  
     Insert into log.log
     set date = "&sysdate"d, time = "&systime"t, user = "&sysuserid",
		 report = "* &Ucc - &yyyy * peps02 (re)calculated *";		  
QUIT;

%mend UPD_peps07;
