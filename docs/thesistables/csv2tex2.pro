
; .csv to .tex table

; csvfile = 'table2_stats_fitavgflux_allpages_050804_ving2.csv'
; texfile = 'table2_stats_fitavgflux_allpages_050804.tex'

csvfile = 'table1_observations_051103.csv'
texfile = 'table1_observations_051103.tex'

maxlines = numlines(csvfile)

openr,clun,csvfile,/get_lun

openw,tlun,texfile,/get_lun

csvline='' 

for iline = 0,maxlines-1 do begin

   readf,clun,csvline
   cparts = strsplit(csvline,/extract,",",/preserve_null)
   help,cparts
;   if n_elements(cparts) ge 12 and iline ge 1 then cparts[12]=cparts[12]+'\degr'
   for ipart = 0,n_elements(cparts)-2 do begin
;; Strip quotes when necessary
      if strmid(cparts[ipart],0,1) eq '"' then $
        cparts[ipart] = strmid(cparts[ipart],1,strlen(cparts[ipart])-2)
;        if (iline gt 0 and ((ipart eq 5) or (ipart eq 6))) then begin
;         if (iline gt 0 and ((ipart eq 5) or (ipart eq 6))) then begin
;            part1 = cparts[ipart]
;            part2int = 0.
;            reads,part1,part2int,format='(f5.2)'
; ;           junk2 = strcompress(junk2,/remove_all)
;            part3 = string(part2int,format='(f5.2)')
;            help,part1
;            help,part3
;            cparts[ipart] = part3
;         endif
;         if (iline gt 0 and ((ipart eq 3) or (ipart eq 4))) then begin
;            part1 = cparts[ipart]
;            part2int = 0.
;            reads,part1,part2int,format='(f5.1)'
; ;           junk2 = strcompress(junk2,/remove_all)
;            part3 = string(part2int,format='(f5.1)')
;            help,part1
;            help,part3
;            cparts[ipart] = part3
;         endif
;       case 1 of
;          ((ipart eq 1) or (ipart eq 3) or (ipart eq 5) or (ipart eq 8)): begin
;             savepart = cparts[ipart]
;          end
;          ((ipart eq 2) or (ipart eq 4) or (ipart eq 6) or (ipart eq 9)): begin
;             prntpart = savepart+' $\pm$ '+cparts[ipart]
;             printf,tlun,prntpart,format='($,a,"& ")'
;          end
;       else: begin
               printf,tlun,cparts[ipart],format='($,a,"& ")'
;               savepart = ''
;            end
;      endcase 
   endfor
   printf,tlun,cparts[n_elements(cparts)-1],format='(a," \\")'
;   printf,tlun
endfor

free_lun,clun
free_lun,tlun

end
