
; .tex table to .csv

; csvfile = 'table2_stats_fitavgflux_allpages_050804_ving2.csv'
; texfile = 'table2_stats_fitavgflux_allpages_050804.tex'

texfile = 'table2_stats_052404_pylos_precsv.tex'
csvfile = 'table2_stats_052404_pylos.csv'

maxlines = numlines(texfile)

openr,tlun,texfile,/get_lun

openw,clun,csvfile,/get_lun

texline='' 
storedline=''

for iline = 0,maxlines-1 do begin

   readf,tlun,texline
;   print,texline
;;
;; Ignore blank or commented lines
;;
   if (strcompress(texline,/remove_all) ne '') and (strmid(texline,0,1) ne '%') then begin
;;;
;;;  Put back together entries that are split across lines
;;;   lines end with '\\'
;;;
      if strmid(strcompress(texline,/remove_all),1,2,/reverse_offset) ne '\\' then begin $
           print, 'Line continues'
           storedline = storedline + texline
      endif else begin
           texline = storedline + texline
           storedline = ''
           print,texline

      tparts = strsplit(texline,/extract,'&',/preserve_null)
      nparts = n_elements(tparts)
      for ipart = 0,nparts-1 do begin
          printf,clun,tparts[ipart],format='(a,",",$)'
      endfor

      printf,clun,''
      endelse


   endif
;    cparts = strsplit(csvline,/extract,",",/preserve_null)

;    if n_elements(cparts) ge 12 and iline ge 1 then cparts[12]=cparts[12]+'\degr'

;    for ipart = 0,n_elements(cparts)-2 do begin
; ;; Strip quotes when necessary
;       if strmid(cparts[ipart],0,1) eq '"' then $
;         cparts[ipart] = strmid(cparts[ipart],1,strlen(cparts[ipart])-2)
; ;        if (iline gt 0 and ((ipart eq 5) or (ipart eq 6))) then begin
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
;               printf,tlun,cparts[ipart],format='($,a,"& ")'
;               savepart = ''
;             end
;       endcase 
;    endfor
;    printf,tlun,cparts[n_elements(cparts)-1],format='(a," \\")'

;   printf,tlun
endfor

free_lun,clun
free_lun,tlun

end
