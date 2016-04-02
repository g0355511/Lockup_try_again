*   20160127  新任務;

*  原始資料期間：20020411~ 20150216;


libname bon 'D:\Documents\For 邦茹\';

PROC IMPORT OUT= WORK.a01 
            DATAFILE= "D:\Documents\For 邦茹\集保資料_1.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=NO;
     DATAROW=2; 
RUN;

data a11;
   set a01;
   rename var2=name    /*  證券簡稱  */
          var3=date    /*  申請日期  */
          var4=amount  /*  數額  */
          var5=type;   /*  申請種類  */
   var3=var3+19110000;  
   stk=left(put(var1,6.));   /*  證券代號  */
   drop var1 var6; 
run;


PROC IMPORT OUT= WORK.A02 
            DATAFILE= "D:\Documents\For 邦茹\集保資料_2.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=no;
     DATAROW=2; 
RUN;

data a12;
   set a02;
   rename var2=name
          var3=date
          var4=amount
          var5=type;
   var3=var3+19110000;  
   stk=left(put(var1,6.));       
   drop var1;
run;          

proc sort data=a11;
   by stk name type date amount; 
   
proc sort data=a12;
   by stk name type date amount; 
run;   



*****************;
*  新朋友加入    ;
*****************;

/*  101/4/3  ~ 1040226*/
data a13;
   infile 'D:\Documents\For 邦茹\FDPTO_clean.TXT';
   input  stk   $  1-6    
          name  $  8-21
          date    23-29
          amount  31-43
          type  $ 45-53;
   date=date+19110000;          
run;     

proc sort data=a13;
   by stk name type date amount; 
quit;      


*********************;
*  連結 3 份集保資料 ;
*********************;
data a2;
   set a11 a12 a13;
   by stk name type date amount; 
run;   
   
proc sort data=a2;
   by stk name type date amount; 
run;



/*  結合來自老師的 3 份集保資料  */
proc sql;
   create table bon.original as
   select stk ,name ,type ,date ,amount
   from a2;
run; 

/*  老師的白名單  */
data a001;
   infile'D:\Documents\For 邦茹\姜老師的白名單.txt';
   input stk   $    1-6;
   
data a002;
   infile'D:\Documents\For 邦茹\姜老師的白名單_new_20150408.txt';
   input stk   $    1-6;
run;
data a00;
   set a001 a002;
proc sort data=a00;
   by stk;
quit;
proc sort data=a00 nodup out=a000;
   by stk;
quit;
   


/*  將原始檔案，與老師的公司樣本結合，存成永久檔bon.original02，以變數teacher哪些是老師的樣本  */
data bon.original02;
   merge bon.original(in=w1) a00(in=w2);
   by stk;
   if w2=1 then teacher=1;  /*  teacher=1 代表是老師白名單的公司  */
   else teacher=0;
   if teacher=1;   /*  只取出白名單公司  */
run;   




/*  SAS常當，所以從這開始  */
/*  重新叫出結合老師兩母檔的永久檔  */

libname bon 'D:\Documents\For 邦茹\';
data a21;
   set bon.original02;
   by stk name type date amount; 
   if first.amount then n=1;
   else n=n+1;
   retain n;
run;


/*  以類型、日期作為加總數額的準則，故有日期變數  */
proc sql;    
   create table a41 as
   select stk,
          name,
          type,
          date,
          sum(amount) as amount1  /*   將公司：同類型（集保/解集保）-->同一天的股數加總: amonut1   */
   from a21
   group by stk,name,date,type      /*  但同一天，不同類型要分開  */
   order by stk,name, date,type;
quit;             


/*  看公司是否存在同一天，同時有集保與解集保  */
*data tmp0;
*   set a41;   
*   by stk date type;
*   if first.date then n=1;
*   else n=n+1;
*   retain n;
*run;
*data tmp1;
*   set tmp0;
*   if n>1;
*run;
*data tmp2;
*   merge tmp0 tmp1(in=w2 rename=(type=type2 amount1=amount2));
*   by stk date;
*   if w2;
*run;   
   
/*  結果：存在  */

data tmp;
   set a41;
   if type='控管確認' then amt=amount1;
   else if type='解除確認' then amt=amount1*(-1);
run;
proc sql;    
   create table tmp1 as
   select stk,
          name,
          date,
          sum(amt) as amt_date  /*   將同一天集保和解除的股數加總，因有些公司同一天出現方向相反地動作   */
   from tmp
   group by stk,name,date
   order by stk,name,date;
quit;

proc sort data=tmp1 out=tmp10 nodup;   /*  存在重複資料的樣本  */
   by stk date;
run;   

/*  計算每次動作的總量狀態  */
data a410;
   set tmp10;
   by stk date;
   if first.stk then amt_cum=amt_date;
   else amt_cum=amt_cum+amt_date;
   retain amt_cum;
run;   

proc sql;    /*  計算一家公司的集保和解除個別的總量（無日期）   */
   create table a42 as
   select stk,
          name,
          type,
          sum(amount) as amount2   /*   將同公司、同類型的數額加總: amonut2   */
   from a21
   group by stk,name,type;
quit;   

/*  測試：集保是否等於解除集保  */
proc sort data=a42;
   by stk type;
run;   
data tmp1;
   set a42;
   by stk type;
   
   lag_amt=lag1(amount2);
   if first.stk then lag_amt=.;
   
   if first.stk then n=1;
   else n=n+1;
   retain n;
run;
data tmp2;
   set tmp1;
   if n=2;
   if amount2=lag_amt then equal=1;   /*  equal=1，公司的集保均解回來  */
   else equal=0;   /*  equal=0，公司的集保和解集保的數量不同，可能時間未到  */
run;

data tmp3;
   merge tmp1 tmp2;
   by stk;
   if equal=0;    /*  IPO後，未曾完全解除閉鎖  */
run;


/*  樣本期間，是否完全解除  */

data tmp411;
   set a410;
   if amt_cum=0;     /*  先取有完全解除管制的樣本  */
data tmp412;
   set tmp411;
   by stk date;
   if first.stk;     /*  取第一個完全解除集保管制的日期  */
   keep stk date;
data tmp413;
   merge a410 tmp412(in=w2 rename=(date=date2));
   by stk; 
   if date<=date2 then before_IPO=1;    /*  before_IPO=1 表 第一次完全解除管制日之前的樣本 */
   else before_IPO=0;
run;  

/*  觀察結果：'D:\Documents\For 邦茹\meeting21050410.sas' 中  */ 


data tmp4;   /*  就是它了  */
*   merge tmp413(in=w2 drop=date2) tmp2(keep=stk equal in=w1) ;
   merge tmp413(in=w2 rename=(date2=date_ulall)) tmp2(keep=stk equal in=w1) ;
   by stk;
*   if equal=. then equal=1;
run;  

data tmp401;
   set tmp4;
   where amt_date<0;
   keep stk date dp;
   by stk date;
   if first.stk then dp=1;
   else dp=dp+1;
   retain dp;
run;

data tmp4010;
   set tmp401;
   by stk dp;
   if last.stk;
   rename dp=count_dp;
   keep stk dp;
run;

%Macro ddpp;
%do i=1 %to 7;
data tmp401&i;
   set tmp401;
   where dp=&i;
   date_dp&i=date;
   keep stk date_dp&i;
run;
%end;

data tmp402;   /*  解除閉鎖的時間  */
   merge tmp4011-tmp4017;
   by stk;
run;

%mend;

%ddpp;      

data tmp403;
   merge tmp4 tmp4010 tmp402;   /*  */
   by stk;
run;

data tmp404;
   set tmp403;
   if equal=1 and before_IPO=0 then delete;   /*  */
   if date_ulall=. then before_IPO=2;   /*  before_IPO=2 表示有解除，卻未完全解除閉鎖的公司  */
run;

data tmp405;
   merge tmp404 tmp401;
   by stk date;
run;   

proc sql;
   create table tmp406 as
   select stk
         ,name
         ,date
         ,amt_date
         ,amt_cum
         ,max(amt_cum) as amt_cum_max
         ,amt_date/max(amt_cum)*100 as amt_date_pt
         ,min(amt_date) as max_dp
         ,amt_cum/max(amt_cum)*100 as amt_cum_pt
         ,dp
         ,*
   from tmp405
   group by stk
   order by stk, date;
quit;   
           
--->20160217;           
           
/*  取出 「未」完全解除集保公司的最後一筆集保資訊  */
*data tmp41;
*   set tmp4;
*   where equal=0;
*   by stk;
*   if last.stk;   
*run;
/*  ps.都接近樣本尾聲  */
  
/*  除集保、解集保，是否有第三種以上的狀況  */
*data tmp3;
*   set tmp1;
*   if n>2;
*run;   /*  結果：沒有  */


/*  以下暫不處理  */
*proc sort data=a410;
*   by stk date;
*quit;
*proc sql;
*   create table tmp3 as
*   select a.stk
*         ,a.date
*         ,a.amt_date
*         ,a.amt_cum
*         ,b.equal
*         ,b.amount2
*         ,b.lag_amt
*   from a410 a left outer join tmp2 b
*   on a.stk=b.stk
*   order by stk
*           ,date;
*quit;
   
*data tmp4;
*   set tmp3;
*   if amount2=. then onlylock=1;   /*  onlylock=1:只有集保資料的公司  */
*   else onlylock=0;  /*  onlylock=0: 有集保、解集保資料的公司  */
*   y=int(date/10000);
*   m=int((date-y*10000)/100);
*   d=date-y*10000-m*100;
*   mdy=mdy(m,d,y);       /*  集保或非集保的事件日MDY  */
*   drop y m d;
*run; 

*proc sort data=tmp4;
*   by stk date;
*run;
   
*data tmp5;
*   set tmp4;
*   by stk date;     
*   lag_mdy=lag1(mdy);
*   if first.stk then lag_mdy=.;  
*run;