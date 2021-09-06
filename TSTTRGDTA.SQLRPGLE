        ctl-opt option(*SRCSTMT) DFTACTGRP(*NO) ACTGRP('AD');

        dcl-ds testpf_ds  extname('TESTPF') qualified inz;
        end-ds;
        dcl-s  fieldSet   char(100) inz;
        dcl-s lib      char(10) inz('PIOLIB');
        dcl-s tbl      char(10) inz('TESTPF');

        dcl-ds storage_ds inz;
               wktbl      char(10);
               wkData     char(100);
        end-ds;

        dcl-ds tblcol_ds     inz;
               wkcol      varchar(128);
               wkdttype   varchar(8);
               wklen      zoned(9);
               wkscale    zoned(9);
        end-ds;

        dcl-s valinsert     char(1000) inz;
        dcl-s tempValC      char(50) inz;
        dcl-s tempValN      zoned(50) inz;
        dcl-s dataTypeConv  char(1000) inz;
        dcl-s dclstmt       char(500) inz;

        dcl-s Q             char(1) inz('''');
        dcl-s beginPos      zoned(9) inz(1);
        dcl-s wkPos         zoned(9) inz(1);
        dcl-s msg           char(100) inz;
        dcl-s actualPos     zoned(9) inz(1);
        dcl-s lastcolDec    ind inz('0');
        dcl-s wkdiv         char(8) inz;
        dcl-s wkdivnum      zoned(8) inz;

        exec sql set option commit = *none, closqlcsr = *endmod, datfmt = *iso;

        //Get fieldset data from testpf..
        exec sql declare c1 cursor for
                 select * from testpf for read only;
        exec sql open c1;
        exec sql fetch next from c1 into :testpf_ds;
        dow sqlcode = 0;
          fieldset = testpf_ds;
          exec sql insert into testpfj values(:tbl, :fieldset);

          exec sql fetch next from c1 into :testpf_ds;
        enddo;
        exec sql close c1;



        exsr segregateFieldValues;

        valInsert = %trim(valInsert) + ' from ' + %trim(lib) + '/' +
                    'TESTPFJ';

        *inlr = *on;

       //segregating field values from data set...
        begsr segregateFieldValues;

        valinsert = 'insert into ' + %trim(lib) + '/' + %Trim(tbl) +
                    ' select ';

        //pick column names length and type for the table to structure data set back...
        dclstmt = 'SELECT COLUMN_NAME , '+
          ' DATA_TYPE, LENGTH, ifnull(NUMERIC_SCALE, 0) '    +
          'FROM syscolumns WHERE table_name = ' +Q+ %trim(tbl) +Q+ ' and ' +
          'table_schema = ' +Q+ %trim(lib) + Q;


        exec sql prepare p3 from :dclstmt;

        exec sql declare c3 cursor for P3;

        exec sql open c3;
        exec sql fetch next from c3 into :tblcol_ds;


        exec sql get diagnostics condition 1 :msg = MESSAGE_TEXT;
        dow sqlcode = 0;

          exsr createInsertValues;

          exec sql fetch next from c3 into :tblcol_ds;
        enddo;


        exec sql close c3;
        endsr;

        //creating string for inserting segregated data values into destinaltion table...
        begsr createInsertValues;

        If beginPos <> 1;
          valInsert = %trim(valInsert) + ',';
        endif;

        select;
          when wkdttype = 'CHAR';

          if lastColDec = *on;
            lastColDec = *off;
          endif;


          valInsert = %trim(valInsert) + ' substr(dataset,' +
                      %char(beginPos) + ', ' + %char(wklen) + ')';
          beginPos = beginPos + wklen;
          actualPos = actualPos + wkLen;

          when wkdttype = 'DECIMAL';
          if lastColDec = *on;
            lastColDec = *off;
          endif;

          wkdivnum = 10**wkscale;
          wkdiv = %char(wkdivnum);
          datatypeConv = ' dec(Dec(Replace(Translate(hex(substr(' +
            'dataset ,' + %char(beginPos) + ', (' +
            %char(wkLen) + '/2) + 1)), ' + Q + 'FF' + Q + ', ' +
            Q + 'CD' + Q + '), ' + Q + 'F' + Q + ', ' + Q + Q + '), ' +
            %char(wkLen) + ', 0 ) * ' +
            'Case When Substr(Right(hex(substr(Dataset, '+
            %char(beginPos) + ', (' +
            %char(wkLen) + '/2) + 1)), 1), 1, 1) = ' + Q + 'F' + Q +
            ' Then 1  Else -1 End)/(' + %trim(wkDiv) + ')';

          valInsert = %trim(valInsert) + %trim(dataTypeConv);
          beginPos = beginPos + (wklen/2) + 1;
          lastcolDec = *on;

          when wkdttype = 'NUMERIC';
          if lastColDec = *on;
            lastColDec = *off;
          endif;

          if wkScale <> 0;
            wkdivnum = 10**wkscale;
            wkdiv = %char(wkdivnum);
          else;
            wkDiv = '1';
          endif;
          valInsert = %trim(valInsert) + ' decimal(substr(dataset,' +
                      %char(beginPos) + ', ' + %char(wklen) + '))/' + wkdiv;
          beginPos = beginPos + wklen;
          actualPos = actualPos + wkLen;


          when wkdttype = 'DATE';
          if lastColDec = *on;
            lastColDec = *off;
          endif;

          valInsert = %trim(valInsert) + ' substr(dataset,' +
                      %char(beginPos) + ', 10)';
          beginPos = beginPos + 10;


          when wkdttype = 'TIME';
          if lastColDec = *on;
            lastColDec = *off;
          endif;

          valInsert = %trim(valInsert) + ' substr(dataset,' +
                      %char(beginPos) + ', 8)';
          beginPos = beginPos + 8;


          when wkdttype = 'TIMESTMP';
          if lastColDec = *on;
            lastColDec = *off;
          endif;

          valInsert = %trim(valInsert) + ' substr(dataset,' +
                      %char(beginPos) + ', 26)';
          beginPos = beginPos + 26;




        endsl;

        endsr;


