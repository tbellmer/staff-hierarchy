/*******************************************************************************
     Program: staff_hierachy.sas
      Author: Tom Bellmer
     Created: 09/25/2021
     Purpose: Creates fictious staff and hierachy data 

                             Modifications in descending order
FL-YYYYMMDD                             Description
----------- --------------------------------------------------------------------
 
         1    1    2    2    3    3    4    4    5    5    6    6    7    7    8
....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0
*******************************************************************************/

libname geo "/home/thomasbellmer0/data/geo";

proc datasets lib = work nolist kill; quit; 

proc format;
  picture phone
    low - high = '0000) 000-0000'
    (prefix = '(');
run;

%let seed = 987; 

/* get top 9 cities based on population and Overland Park */
proc sql;
  create table zipcodes as
    select         z.zip
                 , propcase(z.city) as city
                 , z.state
                 , c.cbsacode
                 , c.cbsaname
                 , c.latitude
                 , c.longitude
                 , zc.areacode
     from          geo.zipcodes z
     inner join    geo.cbsas c
       on          z.cbsa = c.cbsacode
     inner join    sashelp.zipcode zc
       on          z.zip = put(zc.zip, 5.)
     where         zc.zip in(10001, 90001, 60601, 77001, 85001
                      , 19019, 78201, 92101, 75201, 66221)
  ;
quit;
 

data work.staff(keep = pk -- fk_staff);
  call streaminit(&seed);
  attrib
    pk        length =   4
    firstname length =  $8
    lastname  length =  $8
    sex       length =  $1
    email     length = $32
    title     length = $16
    city      length = $32
    state     length =  $2
    zip       length =  $5
    cbsacode  length =  $5
    cbsaname  length = $34
    latitude  length =   8
    longitude length =   8
    phone     length =   6 format = phone.
    img_path  length = $32
    fk_staff  length =   4
  ;

  do t_i = 0 to 3;
    title    = ifc(t_i = 0, 'President', 'Vice President');
    fk_staff = ifn(t_i = 0, ., 1);
    link createdata;
  end;
  mgr_fk_start = pk + 1;

  title = 'Director';
  do fk_staff = 2 to pk;
    do t_i = 1 to ceil(2 * rand('uniform'));
      /* there can be 1 to 2 Directors per VP */
      link createdata;
    end;
  end;
  analyst_fk_start = pk + 1;
 
  title = 'Manager';
  do fk_staff = mgr_fk_start to pk;
    do t_i = 1 to ceil(3 * rand('uniform'));
      /* there can be 1 to 3 managers per Director */
      link createdata;
    end;
  end;

  title = 'Analyst';
  do fk_staff = analyst_fk_start to pk;
    do t_i = 1 to ceil(5 * rand('uniform'));
      /* there can be 1 to 5 analysts per Manager */
      link createdata;
    end;
  end;
  stop;

  createdata:
    pk + 1;
    if pk = 1 then p = 3;
    else p = ceil(obs * rand('uniform'));

    set zipcodes point = p nobs  = obs;

    /* name can be between 3 and 8 characters long  */
    t_len = max(3, ceil(8 * rand('uniform')));
    do _n_ = 1 to t_len;
      if _n_ = 1 then do;
        /* Uppercase "A" starts at ASCII 65 */
        firstname = byte(int(65 + 26 * rand('uniform')));
        lastname  = byte(int(65 + 26 * rand('uniform')));
      end;
      else do;
        /* lowercase "a" starts at ASCII 97 */
        if _n_ <= (t_len - 2) then substr(firstname, _n_, 1) =
          byte(int(97 + 26 * rand('uniform')));
        substr(lastname, _n_, 1) = byte(int(97 + 26 * rand('uniform')));
      end;
    end;
    
    /* 50.97% of population is female per 2019 US Census */
    sex = ifc(rand('uniform') <= 0.5097, 'F', 'M');
    phone = areacode * 10000000 + input(put(ceil(rand('uniform') * 9999999), z7.),7.);
    img_path = 'images/notfound.png';

    if pk = 1 then do;
      firstname = 'Thomas';
      lastname  = 'Bellmer';
      sex       = 'M';
      phone     = 9132216533;
      img_path  = 'images/1.png';
    end;
    else if pk = 2 then do;
      firstname = 'Allan';
      lastname  = 'Bowe';
      sex       = 'M';
      img_path  = 'images/2.png';
    end;
    email = lowcase(cats(firstname, '.', lastname, '@gmail.com'));

    output;
  return;
run;


proc sql;
  create table map as
    select        count(*) as count
                , cbsaname  as label
                , catx(", ", longitude, latitude) as coordinates length = 64
                , longitude
                , latitude
    from          work.staff
    group by      cbsaname
                , coordinates
  ;
quit;


proc sgmap plotdata = map;
  openstreetmap;
  bubble x = longitude y = latitude size = count /
    datalabel = label 
    legendlabel = 'City Count'
    datalabelattrs = (color = red)
  ;
run;
 

proc sql;
  create table work.hierarchy as
    select        e.pk
                , catx(" ", e.firstname, e.lastname) as name length = 32
                , ifc(e.sex = 'F', 'Female', 'Male') as sex length = 6
                , e.title
                , e.city
                , e.state
                , e.zip
                , e.cbsacode
                , e.cbsaname
                , e.latitude
                , e.longitude
                , e.phone
                , e.email
                , catx(" ", m.firstname, m.lastname) as manager length = 32
                , e.img_path
                , e.fk_staff
    from          work.staff e
    left join     work.staff m
      on          e.fk_staff = m.pk
    order by      pk
   ;
quit;


proc export
  data    = work.hierarchy
  outfile = '/home/thomasbellmer0/play/hierarchy.csv'
  dbms    = csv
  replace;
run;