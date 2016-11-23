*** At-risk-poverty-rate anchored at a fixed moment in time (&ref_yr), by age and gender ***;


%macro UPD_li22_anybase(yyyy,Ucc,Uccs,flag) /store;

%let tab=li22_anybase;


PROC DATASETS lib=work kill nolist;
QUIT;

%let cc=%lowcase(&Ucc);
%let yy=%substr(&yyyy,3,2);
%let EU=0;
%if &Uccs=0 %then %let Uccs=("&Ucc");
%else %let EU=1; 

%macro any_year (any_year);
	%let any_yr =%substr(&any_year,3,2);

	%if ((&yyyy > 2005 and &any_year < &yyyy and &Uccs ne "BG" and &Uccs ne "CH" and &Uccs ne "FR" and &Uccs ne "RO") or
		(&any_year > 2005 and &any_year < &yyyy and &Uccs ="BG") or
		(&any_year > 2006 and &any_year < &yyyy and &Uccs ="RO") or
		(&any_year > 2006 and &any_year < &yyyy and &Uccs ="CH") or
		(&yyyy > 2005 and &yyyy < 2008 and &any_year < &yyyy and &Uccs = "FR")	or 
		(&any_year > 2007 and &any_year < &yyyy and &Uccs = "FR"))
	%then %do;
		%let not60=0;

		%if &EU=0 %then %do;

		PROC FORMAT;
		    VALUE f_age (multilabel)
				0 - 17 = "Y_LT18"
				18 - 64 = "Y18-64"
				65 - HIGH = "Y_GE65"
				0 - HIGH = "TOTAL"
				;

			VALUE f_sex (multilabel)
				1 = "M"
				2 = "F"
				1 - 2 = "T";
		RUN;

		PROC SQL /*noprint*/;

		Create Table work.idx as select DISTINCT
			idx.GEO,
			idx.TIME,
			idx.IDX2005 AS IDX_REF_YR,
			idx_2.IDX2005 AS IDX_ANCHOR_YR,
			(100*idx.IDX2005/idx_2.IDX2005) AS IDX,
			(case
				    when (&yyyy > 2006 and &any_year <= 2006 and anchor.DB020 = "MT") then (anchor.ARPT60 / anchor.RATE) 
				    when (&yyyy > 2006 and &any_year <= 2006 and anchor.DB020 = "SI") then (anchor.ARPT60 / anchor.RATE) 
					when (&yyyy > 2008 and &any_year <= 2008 and anchor.DB020 = "CY") then (anchor.ARPT60 /anchor.RATE)
					when (&yyyy > 2008 and &any_year <= 2008 and anchor.DB020 = "SK") then (anchor.ARPT60 /anchor.RATE)
					when (&yyyy > 2011 and &any_year <= 2011 and anchor.DB020 = "EE") then (anchor.ARPT60 /anchor.RATE) 
				    else anchor.ARPT60
				  end) as ARPT60,
			(CALCULATED ARPT60 * CALCULATED IDX / 100) as ARPT60idx
		from idb.idx2005 as idx
			left join idb.idx2005 as idx_2 on (idx.GEO = idx_2.GEO)
				left join idb.IDB&any_yr as anchor on (idx.GEO = anchor.DB020)
			where idx.GEO in &Uccs and idx.TIME = &yyyy and idx_2.TIME = &any_year;
		run;

		
	 
		Create table work.idb as select
					db.DB010, db.DB020, db.DB030, db.RB030, db.RB050a,
					db.Age, db.RB090, db.EQ_INC20,
					idx.idx,
				    idx.ARPT60idx,
			       (case
				    when db.EQ_INC20 < idx.ARPT60idx then 1
					else 0
					end) as ARPT60ix
		 	from idb.IDB&yy as db left join work.idx as idx on (db.DB010 = idx.TIME) AND (db.DB020 = idx.GEO)
			where db.age ge 0 and db.DB010 = &yyyy and db.DB020 in &Uccs;

		QUIT;

		PROC TABULATE data=work.idb out=Ti;
			FORMAT AGE f_age15.;
			FORMAT RB090 f_sex.;
			VAR RB050a;
			CLASS AGE /MLF;
			CLASS RB090 /MLF;
			CLASS ARPT60ix;
			CLASS DB020;
			TABLE DB020 * AGE * RB090, ARPT60ix * RB050a * (RowPctSum N Sum) /printmiss;
		RUN;


		PROC SQL;

		CREATE TABLE work.old_flag AS
				SELECT distinct
					time,
					geo,
					anchor,
					sex,
					iflag
				FROM rdb.&tab
				WHERE  time = &yyyy and geo="&Ucc"  ;

		CREATE TABLE work.li22_anybase AS
		SELECT 
			Ti.DB020 as geo FORMAT=$5. LENGTH=5,
			&yyyy as time,
			&any_year as Anchor,
			Ti.Age,
			Ti.RB090 as sex,
			Ti.ARPT60ix,
			"PC_POP" as unit,
			Ti.RB050a_PctSum_1101 as ivalue,
			old_flag.iflag as iflag, 
			(case when sum(Ti.RB050a_N) < 20  then 2
				  when sum(Ti.RB050a_N) < 50 then 1
				  else 0
			      end) as unrel,
			Ti.RB050a_N as n,
			sum(Ti.RB050a_N) as ntot,
			sum(Ti.RB050a_Sum) as totwgh,
			"&sysdate" as lastup,
			"&sysuserid" as	lastuser 
		FROM Ti 
			LEFT JOIN work.old_flag ON (Ti.DB020=old_flag.geo) AND (&any_year=old_flag.anchor) AND ( Ti.RB090 = old_flag.sex)
		GROUP BY Ti.DB020, ti.AGE, ti.RB090
		ORDER BY Ti.DB020, ti.AGE, ti.RB090;
		QUIT;

		* Update RDB;
		DATA  rdb.li22_anybase (drop= ARPT60ix);
		set rdb.li22_anybase (where=(not(time = &yyyy and geo = "&Ucc" and anchor = &any_year )))
		    work.li22_anybase;
			where ARPT60ix=1;
		RUN;

		%end;

		* EU aggregates;
		%if &EU %then %do;
			%let tab=li22_anybase;
			%let grpdim=age, sex, anchor, unit;
			%EUVALS(&Ucc,&Uccs);
		%end;
	%end;
%mend any_year;
%any_year(2005);
/*%any_year(2006);
%any_year(2007);*/
%any_year(2008);/*
%any_year(2009);*/
%any_year(2010);

PROC SQL;  
     Insert into log.log
     set date = "&sysdate"d, time = "&systime"t, user = "&sysuserid",
		 report = "* &Ucc - &yyyy * li22_anybase (re)calculated *";		  
QUIT;


%mend UPD_li22_anybase;
