; ==========================================================================
;  PARKVAULT - Smart Parking Fee Management System
;  CT073-3-2 Computer System Low Level Techniques (CSLLT)
;  NASM, 32-bit x86, Linux (int 0x80 system calls)
;
;  CRUD     : Park (Create), View/Search (Read), Update, Check-out (Delete)
;  Arithmetic: ADD, SUB, MUL, DIV
;  Loops/Jumps: menu loop, table loops, retry loops, jcc / jmp branching
;  Extras   : ANSI colours, TXT + CSV file saving, input validation
; ==========================================================================

%define MAXSLOTS 10
%define PLATELEN 9                      ; 8 characters + NUL terminator
%define NAMELEN  21                     ; 20 characters + NUL terminator

%macro PRINT 1                          ; print a NUL-terminated string
    push esi
    mov esi, %1
    call print_str
    pop esi
%endmacro

%macro COLOR 1                          ; switch colour (ignored for files)
    push esi
    mov esi, %1
    call set_color
    pop esi
%endmacro

%macro CHAR 1                           ; print one character
    push eax
    mov al, %1
    call print_char
    pop eax
%endmacro

%macro NUM 1                            ; print a number stored in memory
    push eax
    mov eax, [%1]
    call print_num
    pop eax
%endmacro

; ==========================================================================
section .data
; ---- ANSI colour codes (warm 256-colour palette, soft not neon) ----------
c_reset   db 27,"[0m",0
c_coral   db 27,"[38;5;167m",0          ; soft coral      - errors / exit
c_olive   db 27,"[38;5;143m",0          ; warm olive      - success
c_honey   db 27,"[38;5;222m",0          ; honey yellow    - menu / info
c_sand    db 27,"[38;5;180m",0          ; sandy tan       - secondary items
c_rose    db 27,"[38;5;174m",0          ; dusty rose      - status / pause
c_peach   db 27,"[38;5;216m",0          ; apricot peach   - prompts / borders
c_cream   db 27,"[1;38;5;230m",0        ; bold cream      - highlights
c_banner  db 27,"[1;38;5;230;48;5;130m",0   ; cream on burnt orange
c_head    db 27,"[1;38;5;52;48;5;223m",0    ; dark brown on soft peach
c_clear   db 27,"[2J",0                 ; clear screen
c_clear2  db 27,"[H",0                  ; cursor to top-left

nl        db 10,0

; ---- menu / banner --------------------------------------------------------
m_t1 db "  =============================================================  ",10,0
m_t2 db "    P A R K V A U L T  -  Smart Parking Fee Management System    ",10,0
m_t3 db "  =============================================================  ",10,0

m_menu1 db "   [1] Park Vehicle              (Create)",10,0
m_menu2 db "   [2] View Parking Lot          (Read)",10,0
m_menu3 db "   [3] Search Vehicle by Plate   (Read)",10,0
m_menu4 db "   [4] Update Vehicle Record     (Update)",10,0
m_menu5 db "   [5] Check-out and Pay         (Delete)",10,0
m_menu6 db "   [6] Daily Summary",10,0
m_menu7 db "   [7] Save Reports              (TXT + CSV)",10,0
m_menu8 db "   [8] Exit",10,0
m_status db "   Lot status : ",0
m_of     db " of ",0
m_occ    db " slots occupied",10,10,0

p_choice db "  Enter your choice (1-8): ",0
m_pause  db 10,"  Press Enter to continue...",0

; ---- table ----------------------------------------------------------------
m_tline db "  +------+----------+--------------+-------+-----------+",10,0
m_thead db "  | SLOT | PLATE    | VEHICLE TYPE | ENTRY | STATUS    |",10,0
m_bar    db "  | ",0
m_slotl  db "  |  ",0
m_slotr  db "  | ",0
m_sep    db " | ",0
m_barend db " |",10,0
m_dash   db "-",0
m_occupied db "OCCUPIED",0
m_free     db "FREE",0

; ---- vehicle types / rates ------------------------------------------------
t_moto db "Motorcycle",0
t_car  db "Car",0
t_van  db "Van/Truck",0
type_names dd t_moto, t_car, t_van
rates      dd 1, 2, 4                   ; RM per hour
denoms     dd 50, 20, 10, 5, 1          ; change denominations (RM)

m_types1 db "  Vehicle types:",10,0
m_types2 db "   [1] Motorcycle  - RM1 per hour",10,0
m_types3 db "   [2] Car         - RM2 per hour",10,0
m_types4 db "   [3] Van/Truck   - RM4 per hour",10,0

; ---- prompts --------------------------------------------------------------
p_plate  db "  Enter plate number (1-8 letters/digits): ",0
p_type   db "  Select vehicle type (1-3): ",0
p_name   db "  Enter driver name (1-20 letters/spaces): ",0
p_in_h   db "  Entry hour   (0-23): ",0
p_in_m   db "  Entry minute (0-59): ",0
p_out_h  db "  Exit hour    (0-23): ",0
p_out_m  db "  Exit minute  (0-59): ",0
p_slot   db "  Enter slot number (0 = cancel): ",0
p_member db "  Is the customer a member? (1 = Yes, 0 = No): ",0
p_paid   db "  Enter amount paid (RM): ",0
p_upd    db "  Choose an option (0-4): ",0

m_upd1 db "  What would you like to update?",10,0
m_upd2 db "   [1] Plate number",10,0
m_upd3 db "   [2] Vehicle type",10,0
m_upd4 db "   [3] Entry time",10,0
m_upd6 db "   [4] Driver name",10,0
m_upd5 db "   [0] Back to main menu",10,0

; ---- messages -------------------------------------------------------------
m_inv1   db "  [!] Invalid input. Enter a number from ",0
m_inv2   db " to ",0
m_dot    db ".",10,0
m_badname db "  [!] Invalid name. Use 1-20 letters or spaces only.",10,0
m_badplate db "  [!] Invalid plate. Use 1-8 letters or digits only.",10,0
m_full   db "  [!] The parking lot is full.",10,0
m_dup    db "  [!] That plate is already parked in slot ",0
m_slotempty db "  [!] That slot is empty. Choose an occupied slot.",10,0
m_notfound  db "  [!] No vehicle with that plate was found.",10,0
m_assigned  db "  Assigned parking slot: ",0
m_parked    db "  [OK] Vehicle parked successfully.",10,0
m_updated   db "  [OK] Record updated.",10,0
m_checkedout db "  [OK] Check-out complete. Slot is now free.",10,0
m_nolots    db "  [!] No occupied slots to display.",10,0
m_fileerr   db "  [!] Could not open file for writing.",10,0
m_saved1    db "  [OK] Reports saved to: parking_status.txt and parking_status.csv",10,0
m_saved2    db "       Logs: parked_vehicles.txt, receipts.txt and transactions.csv",10,0
m_bye       db 10,"  Thank you for using ParkVault. Goodbye!",10,10,0
m_cap       db "  Daily maximum rate applied (10 x hourly rate).",10,0
m_free_exit db "  Free exit - within the 15-minute grace period.",10,0

; ---- vehicle detail labels --------------------------------------------------
v_head   db 10,"  ---------------- Vehicle Details ----------------",10,0
v_slot   db "  Slot         : ",0
v_plate  db "  Plate        : ",0
v_name   db "  Driver       : ",0
v_type   db "  Vehicle type : ",0
v_entry  db "  Entry time   : ",0

; ---- receipt labels -------------------------------------------------------------
r_top    db 10,"  ================ PARKVAULT RECEIPT =================",10,0
r_exit   db "  Exit time    : ",0
r_dur    db "  Duration     : ",0
r_min    db " minutes",10,0
r_hours  db "  Billable hrs : ",0
r_rate   db "  Rate / hour  : RM",0
r_gross  db "  Gross fee    : RM",0
r_disc   db "  Member disc. : RM",0
r_total  db "  TOTAL DUE    : RM",0
r_paid   db "  Amount paid  : RM",0
r_change db "  Change       : RM",0
r_given  db "  Change given :",10,0
r_note1  db "     RM",0
r_note2  db " x ",0
r_bottom db "  ====================================================",10,0

; ---- summary labels -----------------------------------------------------------------
s_head   db 10,"  ================= DAILY SUMMARY =================",10,0
s_occ    db "  Occupied slots  : ",0
s_free   db "  Free slots      : ",0
s_pct    db "  Occupancy       : ",0
s_pct2   db "%",10,0
s_bar    db "  Lot usage       : [",0
s_barend db "]",10,0
s_rev    db "  Total revenue   : RM",0
s_served db "  Vehicles served : ",0
s_avg    db "  Average fee     : RM",0
s_bottom db "  =================================================",10,0

; ---- file names and file text ----------------------------------------------------
f_status_txt db "parking_status.txt",0
f_status_csv db "parking_status.csv",0
f_receipts   db "receipts.txt",0
f_trans_csv  db "transactions.csv",0
f_parked     db "parked_vehicles.txt",0

h_txt   db "PARKVAULT - PARKING STATUS REPORT",10,0
h_csv_status db "Slot,Status,Plate,Driver,Vehicle_Type,Entry_Time",10,0
h_csv_trans  db "Plate,Driver,Vehicle_Type,Entry,Exit,Duration_Min,Billable_Hours,Rate_RM,Gross_RM,Discount_RM,Net_RM,Paid_RM,Change_RM",10,0
s_occ_csv db "OCCUPIED",0
s_free_csv db "FREE,,,,",0

h_parked1 db "PARKVAULT - PARKED VEHICLE LOG (who parked, when they came in and left)",10,0
h_parked2 db "Event | Slot | Plate    | Driver               | Type       | Time",10,0
h_parked3 db "------+------+----------+----------------------+------------+------",10,0
e_in      db "IN    ",0
e_out     db "OUT   ",0

out_fd dd 1                              ; 1 = screen, otherwise a file

; ==========================================================================
section .bss
slot_used   resb MAXSLOTS
slot_type   resb MAXSLOTS
slot_entry  resw MAXSLOTS
slot_plate  resb MAXSLOTS*PLATELEN
plate_tmp   resb PLATELEN
slot_name   resb MAXSLOTS*NAMELEN
name_tmp    resb NAMELEN
line_buf    resb 64
rdbuf       resb 1
chbuf       resb 1

tmp_slot    resd 1
tmp_type    resd 1
tmp_entry   resd 1
tmp_occ     resd 1
tmp_size    resd 1
fd_tmp      resd 1
tmp_logtime resd 1
tmp_logevt  resd 1
tmp_slot2   resd 1

total_revenue   resd 1
vehicles_served resd 1

b_slot   resd 1
b_exit   resd 1
b_dur    resd 1
b_hours  resd 1
b_rate   resd 1
b_gross  resd 1
b_disc   resd 1
b_net    resd 1
b_paid   resd 1
b_change resd 1
b_member resd 1
b_capped resd 1

; ==========================================================================
section .text
global _start

_start:
; --------------------------------------------------------------------------
;  MAIN MENU LOOP  (loop + conditional / unconditional jumps)
; --------------------------------------------------------------------------
main_menu:
    call draw_menu
    mov esi, p_choice
    mov ebx, 1
    mov ecx, 8
    call get_number                    ; eax = menu choice (validated 1-8)

    cmp eax, 1
    je  do_park
    cmp eax, 2
    je  do_view
    cmp eax, 3
    je  do_search
    cmp eax, 4
    je  do_update
    cmp eax, 5
    je  do_checkout
    cmp eax, 6
    je  do_summary
    cmp eax, 7
    je  do_save
    jmp do_exit_clean                  ; choice 8

do_park:
    call park_vehicle
    jmp  menu_next
do_view:
    call view_lot
    jmp  menu_next
do_search:
    call search_vehicle
    jmp  menu_next
do_update:
    call update_vehicle
    jmp  menu_next
do_checkout:
    call checkout
    jmp  menu_next
do_summary:
    call show_summary
    jmp  menu_next
do_save:
    call save_reports
menu_next:
    call pause_enter
    jmp  main_menu                     ; unconditional jump: back to the menu

do_exit_clean:
    call save_reports                  ; auto-save before leaving
    COLOR c_peach
    PRINT m_bye
    COLOR c_reset
    mov eax, 1                         ; sys_exit
    xor ebx, ebx
    int 0x80

; ==========================================================================
;  OUTPUT HELPERS  (every helper preserves all registers)
; ==========================================================================
print_str:                             ; esi = NUL-terminated string
    pushad
    xor ecx, ecx
.len:
    cmp byte [esi+ecx], 0
    je  .got
    inc ecx
    jmp .len
.got:
    mov edx, ecx                       ; length
    mov ecx, esi                       ; buffer
    mov ebx, [out_fd]
    mov eax, 4                         ; sys_write
    int 0x80
    popad
    ret

print_char:                            ; al = character
    pushad
    mov [chbuf], al
    mov ecx, chbuf
    mov edx, 1
    mov ebx, [out_fd]
    mov eax, 4
    int 0x80
    popad
    ret

print_num:                             ; eax = unsigned number
    pushad
    mov ebx, 10
    xor ecx, ecx
.div:
    xor edx, edx
    div ebx                            ; DIV: eax = quotient, edx = digit
    push edx
    inc ecx
    test eax, eax
    jnz .div
.out:
    pop eax
    add al, '0'                        ; ADD: digit -> ASCII
    call print_char
    dec ecx
    jnz .out
    popad
    ret

print_num2:                            ; eax = number, at least 2 digits
    cmp eax, 10
    jae .big
    push eax
    mov al, '0'
    call print_char
    pop eax
.big:
    call print_num
    ret

print_time:                            ; eax = minutes since midnight -> HH:MM
    pushad
    xor edx, edx
    mov ebx, 60
    div ebx                            ; DIV: eax = hours, edx = minutes
    push edx
    call print_num2
    mov al, ':'
    call print_char
    pop eax
    call print_num2
    popad
    ret

print_str_pad:                         ; esi = string, ecx = column width
    pushad
    xor edx, edx
.len:
    cmp byte [esi+edx], 0
    je  .got
    inc edx
    jmp .len
.got:
    call print_str
    sub ecx, edx                       ; SUB: padding = width - length
    jbe .done
.sp:
    mov al, ' '
    call print_char
    dec ecx
    jnz .sp
.done:
    popad
    ret

set_color:                             ; esi = ANSI string (screen only)
    cmp dword [out_fd], 1
    jne .skip
    call print_str
.skip:
    ret

; ==========================================================================
;  INPUT HELPERS
; ==========================================================================
read_line:                             ; line_buf <- one line, eax = length
    push ebx
    push ecx
    push edx
    push edi
    xor edi, edi
.rd:
    mov eax, 3                         ; sys_read, one byte at a time
    mov ebx, 0
    mov ecx, rdbuf
    mov edx, 1
    int 0x80
    cmp eax, 1
    jne .eof                           ; end of input: leave the program
    mov al, [rdbuf]
    cmp al, 10
    je  .done
    cmp al, 13
    je  .rd
    cmp edi, 62
    jae .rd                            ; buffer full: ignore extra characters
    mov [line_buf+edi], al
    inc edi
    jmp .rd
.done:
    mov byte [line_buf+edi], 0
    mov eax, edi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
.eof:
    jmp do_exit_clean

parse_number:                          ; line_buf -> eax, CF=1 when invalid
    push ebx
    push ecx
    push edx
    push esi
    xor eax, eax
    xor ecx, ecx
    mov esi, line_buf
.p:
    movzx edx, byte [esi]
    test dl, dl
    jz  .end
    cmp dl, '0'
    jb  .bad
    cmp dl, '9'
    ja  .bad
    sub edx, '0'                       ; SUB: ASCII -> digit
    imul eax, eax, 10                  ; MUL: shift previous digits left
    add eax, edx                       ; ADD: add new digit
    inc ecx
    cmp ecx, 7
    ja  .bad
    inc esi
    jmp .p
.end:
    test ecx, ecx
    jz  .bad
    clc
    jmp .ret
.bad:
    stc
.ret:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

get_number:                            ; esi = prompt, ebx = min, ecx = max
    push edx                           ; returns eax (validated)
    push edi
    mov edi, esi
.ask:
    COLOR c_peach
    mov esi, edi
    call print_str
    COLOR c_reset
    call read_line
    call parse_number
    jc  .invalid
    cmp eax, ebx
    jb  .invalid
    cmp eax, ecx
    ja  .invalid
    pop edi
    pop edx
    ret
.invalid:
    COLOR c_coral
    PRINT m_inv1
    push eax
    mov eax, ebx
    call print_num
    PRINT m_inv2
    mov eax, ecx
    call print_num
    pop eax
    PRINT m_dot
    COLOR c_reset
    jmp .ask

get_time:                              ; esi = hour prompt, edi = minute prompt
    push ebx                           ; returns eax = minutes since midnight
    push ecx
    push edx
    push edi
    mov ebx, 0
    mov ecx, 23
    call get_number
    mov edx, 60
    mul edx                            ; MUL: hours x 60
    push eax
    mov esi, edi
    mov ebx, 0
    mov ecx, 59
    call get_number
    pop edx
    add eax, edx                       ; ADD: + minutes
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

get_plate:                             ; validates, upper-cases -> plate_tmp
    pushad
.ask:
    COLOR c_peach
    PRINT p_plate
    COLOR c_reset
    call read_line
    cmp eax, 1
    jb  .bad
    cmp eax, 8
    ja  .bad
    xor ecx, ecx
.chk:
    movzx edx, byte [line_buf+ecx]
    test dl, dl
    jz  .ok
    cmp dl, 'a'
    jb  .notlow
    cmp dl, 'z'
    ja  .notlow
    sub dl, 32                         ; SUB: lower-case -> upper-case
.notlow:
    cmp dl, '0'
    jb  .bad
    cmp dl, '9'
    jbe .store
    cmp dl, 'A'
    jb  .bad
    cmp dl, 'Z'
    ja  .bad
.store:
    mov [plate_tmp+ecx], dl
    inc ecx
    jmp .chk
.ok:
    mov byte [plate_tmp+ecx], 0
    popad
    ret
.bad:
    COLOR c_coral
    PRINT m_badplate
    COLOR c_reset
    jmp .ask

get_name:                              ; validates letters/spaces -> name_tmp
    pushad
.ask:
    COLOR c_peach
    PRINT p_name
    COLOR c_reset
    call read_line
    cmp eax, 1
    jb  .bad
    cmp eax, 20
    ja  .bad
    xor ecx, ecx
    xor ebx, ebx                       ; ebx counts letters (a name of only spaces is rejected)
.chk:
    movzx edx, byte [line_buf+ecx]
    test dl, dl
    jz  .end
    cmp dl, ' '
    je  .store
    cmp dl, 'A'
    jb  .bad
    cmp dl, 'Z'
    jbe .letter
    cmp dl, 'a'
    jb  .bad
    cmp dl, 'z'
    ja  .bad
.letter:
    inc ebx
.store:
    mov [name_tmp+ecx], dl
    inc ecx
    jmp .chk
.end:
    test ebx, ebx
    jz  .bad
    mov byte [name_tmp+ecx], 0
    popad
    ret
.bad:
    COLOR c_coral
    PRINT m_badname
    COLOR c_reset
    jmp .ask

name_addr:                             ; ebx = slot index -> esi = name address
    push eax
    push ecx
    push edx
    mov eax, ebx
    mov ecx, NAMELEN
    mul ecx                            ; MUL: index x 21
    lea esi, [slot_name+eax]
    pop edx
    pop ecx
    pop eax
    ret

store_name:                            ; ebx = slot index, copies name_tmp
    pushad
    call name_addr
    mov edi, esi
    mov esi, name_tmp
    mov ecx, NAMELEN
.cp:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .cp
    popad
    ret

get_type:                              ; eax = vehicle type 1-3
    COLOR c_honey
    PRINT m_types1
    PRINT m_types2
    PRINT m_types3
    PRINT m_types4
    COLOR c_reset
    mov esi, p_type
    mov ebx, 1
    mov ecx, 3
    call get_number
    ret

pause_enter:
    pushad
    COLOR c_rose
    PRINT m_pause
    COLOR c_reset
    call read_line
    popad
    ret

; ==========================================================================
;  SLOT / RECORD HELPERS
; ==========================================================================
plate_addr:                            ; ebx = slot index -> esi = plate address
    push eax
    push ecx
    push edx
    mov eax, ebx
    mov ecx, PLATELEN
    mul ecx                            ; MUL: index x 9
    lea esi, [slot_plate+eax]
    pop edx
    pop ecx
    pop eax
    ret

store_plate:                           ; ebx = slot index, copies plate_tmp
    pushad
    call plate_addr
    mov edi, esi
    mov esi, plate_tmp
    mov ecx, PLATELEN
.cp:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .cp
    popad
    ret

count_occupied:                        ; eax = number of occupied slots
    push ebx
    push ecx
    xor ebx, ebx
    xor ecx, ecx
.c:
    cmp ebx, MAXSLOTS
    jae .done
    cmp byte [slot_used+ebx], 1
    jne .n
    inc ecx
.n:
    inc ebx
    jmp .c
.done:
    mov eax, ecx
    pop ecx
    pop ebx
    ret

find_free_slot:                        ; eax = first free slot or -1
    push ebx
    xor ebx, ebx
.f:
    cmp ebx, MAXSLOTS
    jae .none
    cmp byte [slot_used+ebx], 0
    je  .found
    inc ebx
    jmp .f
.found:
    mov eax, ebx
    jmp .out
.none:
    mov eax, -1
.out:
    pop ebx
    ret

find_plate:                            ; plate_tmp -> eax = slot index or -1
    push ebx
    push ecx
    push esi
    push edi
    xor ebx, ebx
.next:
    cmp ebx, MAXSLOTS
    jae .none
    cmp byte [slot_used+ebx], 1
    jne .skip
    call plate_addr
    mov edi, plate_tmp
.cmp:
    mov al, [esi]
    cmp al, [edi]
    jne .skip
    test al, al
    jz  .found
    inc esi
    inc edi
    jmp .cmp
.skip:
    inc ebx
    jmp .next
.found:
    mov eax, ebx
    jmp .done
.none:
    mov eax, -1
.done:
    pop edi
    pop esi
    pop ecx
    pop ebx
    ret

select_slot:                           ; eax = occupied slot index, -1 = cancel
    push ebx
    push ecx
.ask:
    mov esi, p_slot
    mov ebx, 0
    mov ecx, MAXSLOTS
    call get_number
    test eax, eax
    jz  .cancel
    dec eax
    cmp byte [slot_used+eax], 1
    je  .ok
    COLOR c_coral
    PRINT m_slotempty
    COLOR c_reset
    jmp .ask
.cancel:
    mov eax, -1
.ok:
    pop ecx
    pop ebx
    ret

show_vehicle:                          ; ebx = slot index
    pushad
    COLOR c_peach
    PRINT v_head
    COLOR c_reset
    PRINT v_slot
    mov eax, ebx
    inc eax
    call print_num2
    PRINT nl
    PRINT v_plate
    COLOR c_honey
    call plate_addr
    call print_str
    COLOR c_reset
    PRINT nl
    PRINT v_name
    call name_addr
    call print_str
    PRINT nl
    PRINT v_type
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov esi, [type_names+eax*4]
    call print_str
    PRINT nl
    PRINT v_entry
    movzx eax, word [slot_entry+ebx*2]
    call print_time
    PRINT nl
    popad
    ret

; ==========================================================================
;  CREATE - park a vehicle
; ==========================================================================
park_vehicle:
    pushad
    call find_free_slot
    cmp eax, -1
    jne .have
    COLOR c_coral
    PRINT m_full
    COLOR c_reset
    jmp .done
.have:
    mov [tmp_slot], eax
    COLOR c_olive
    PRINT m_assigned
    inc eax
    call print_num2
    PRINT nl
    COLOR c_reset
    call get_plate
    call find_plate
    cmp eax, -1
    je  .unique
    COLOR c_coral
    PRINT m_dup
    inc eax
    call print_num2
    PRINT nl
    COLOR c_reset
    jmp .done
.unique:
    call get_name
    call get_type
    mov [tmp_type], eax
    mov esi, p_in_h
    mov edi, p_in_m
    call get_time
    mov [tmp_entry], eax
    mov ebx, [tmp_slot]
    mov byte [slot_used+ebx], 1
    call store_plate
    call store_name
    mov eax, [tmp_type]
    mov [slot_type+ebx], al
    mov eax, [tmp_entry]
    mov [slot_entry+ebx*2], ax
    COLOR c_olive
    PRINT m_parked
    COLOR c_reset
    call show_vehicle
    mov esi, e_in                      ; write the arrival into parked_vehicles.txt
    movzx eax, word [slot_entry+ebx*2]
    call log_parked
.done:
    popad
    ret

; ==========================================================================
;  READ - view the whole parking lot
; ==========================================================================
view_lot:
    pushad
    COLOR c_peach
    PRINT m_tline
    COLOR c_head
    PRINT m_thead
    COLOR c_peach
    PRINT m_tline
    COLOR c_reset
    xor ebx, ebx
.row:
    cmp ebx, MAXSLOTS
    jae .end
    PRINT m_slotl
    mov eax, ebx
    inc eax
    call print_num2
    PRINT m_slotr
    cmp byte [slot_used+ebx], 1
    jne .free
    COLOR c_honey
    call plate_addr
    mov ecx, 8
    call print_str_pad
    COLOR c_reset
    PRINT m_sep
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov esi, [type_names+eax*4]
    mov ecx, 12
    call print_str_pad
    PRINT m_sep
    movzx eax, word [slot_entry+ebx*2]
    call print_time
    PRINT m_sep
    COLOR c_coral
    mov esi, m_occupied
    mov ecx, 9
    call print_str_pad
    COLOR c_reset
    jmp .endrow
.free:
    mov esi, m_dash
    mov ecx, 8
    call print_str_pad
    PRINT m_sep
    mov esi, m_dash
    mov ecx, 12
    call print_str_pad
    PRINT m_sep
    mov esi, m_dash
    mov ecx, 5
    call print_str_pad
    PRINT m_sep
    COLOR c_olive
    mov esi, m_free
    mov ecx, 9
    call print_str_pad
    COLOR c_reset
.endrow:
    PRINT m_barend
    inc ebx
    jmp .row
.end:
    COLOR c_peach
    PRINT m_tline
    COLOR c_reset
    popad
    ret

; ==========================================================================
;  READ - search by plate
; ==========================================================================
search_vehicle:
    pushad
    call get_plate
    call find_plate
    cmp eax, -1
    jne .found
    COLOR c_coral
    PRINT m_notfound
    COLOR c_reset
    jmp .done
.found:
    mov ebx, eax
    call show_vehicle
.done:
    popad
    ret

; ==========================================================================
;  UPDATE - edit plate / type / entry time of a parked vehicle
; ==========================================================================
update_vehicle:
    pushad
    call view_lot
    call select_slot
    cmp eax, -1
    je  .back
    mov [tmp_slot], eax
.menu:
    mov ebx, [tmp_slot]
    call show_vehicle
    COLOR c_honey
    PRINT m_upd1
    PRINT m_upd2
    PRINT m_upd3
    PRINT m_upd4
    PRINT m_upd6
    PRINT m_upd5
    COLOR c_reset
    mov esi, p_upd
    mov ebx, 0
    mov ecx, 4
    call get_number
    cmp eax, 1
    je  .plate
    cmp eax, 2
    je  .type
    cmp eax, 3
    je  .entry
    cmp eax, 4
    je  .name
    jmp .back
.name:
    call get_name
    mov ebx, [tmp_slot]
    call store_name
    jmp .saved
.plate:
    call get_plate
    call find_plate
    cmp eax, -1
    je  .plate_ok
    cmp eax, [tmp_slot]
    je  .plate_ok                      ; same vehicle, same plate
    COLOR c_coral
    PRINT m_dup
    inc eax
    call print_num2
    PRINT nl
    COLOR c_reset
    jmp .menu
.plate_ok:
    mov ebx, [tmp_slot]
    call store_plate
    jmp .saved
.type:
    call get_type
    mov ebx, [tmp_slot]
    mov [slot_type+ebx], al
    jmp .saved
.entry:
    mov esi, p_in_h
    mov edi, p_in_m
    call get_time
    mov ebx, [tmp_slot]
    mov [slot_entry+ebx*2], ax
.saved:
    COLOR c_olive
    PRINT m_updated
    COLOR c_reset
    jmp .menu
.back:
    popad
    ret

; ==========================================================================
;  DELETE - check-out, billing, payment, change, logging
; ==========================================================================
checkout:
    pushad
    call view_lot
    call select_slot
    cmp eax, -1
    je  .done
    mov [b_slot], eax
    mov ebx, eax
    movzx eax, word [slot_entry+ebx*2]
    mov [tmp_entry], eax
    call show_vehicle

    mov esi, p_out_h
    mov edi, p_out_m
    call get_time
    mov [b_exit], eax

    ; ---- duration = exit - entry (add 24h if the stay crossed midnight) ----
    mov eax, [b_exit]
    mov edx, [tmp_entry]
    cmp eax, edx
    jae .nowrap
    add eax, 1440                      ; ADD: crossed midnight
.nowrap:
    sub eax, edx                       ; SUB: duration in minutes
    mov [b_dur], eax

    ; ---- billable hours (rounded up), first 15 minutes are free -------------
    cmp eax, 15
    ja  .charge
    mov dword [b_hours], 0
    jmp .rate
.charge:
    add eax, 59                        ; ADD: so that DIV rounds up
    xor edx, edx
    mov ecx, 60
    div ecx                            ; DIV: minutes -> hours
    mov [b_hours], eax

.rate:
    mov ebx, [b_slot]
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov eax, [rates+eax*4]
    mov [b_rate], eax

    mov eax, [b_hours]
    mul dword [b_rate]                 ; MUL: hours x rate
    mov [b_gross], eax

    mov eax, [b_rate]                  ; daily cap = 10 x hourly rate
    mov ecx, 10
    mul ecx                            ; MUL
    mov dword [b_capped], 0
    cmp [b_gross], eax
    jbe .nocap
    mov [b_gross], eax
    mov dword [b_capped], 1
.nocap:
    ; ---- member discount: 10 percent --------------------------------------
    mov esi, p_member
    mov ebx, 0
    mov ecx, 1
    call get_number
    mov [b_member], eax
    mov dword [b_disc], 0
    cmp dword [b_member], 1
    jne .nodisc
    mov eax, [b_gross]
    xor edx, edx
    mov ecx, 10
    div ecx                            ; DIV: 10 percent of the fee
    mov [b_disc], eax
.nodisc:
    mov eax, [b_gross]
    sub eax, [b_disc]                  ; SUB: net fee
    mov [b_net], eax

    call print_bill

    ; ---- payment ---------------------------------------------------------------------
    cmp dword [b_net], 0
    je  .nopay
    mov esi, p_paid
    mov ebx, [b_net]
    mov ecx, 9999
    call get_number
    mov [b_paid], eax
    sub eax, [b_net]                   ; SUB: change due
    mov [b_change], eax
    jmp .paid
.nopay:
    mov dword [b_paid], 0
    mov dword [b_change], 0
.paid:
    call print_payment
    COLOR c_olive
    PRINT m_checkedout
    COLOR c_reset

    ; ---- totals, logs, free the slot ---------------------------------------------
    mov eax, [b_net]
    add [total_revenue], eax           ; ADD: running revenue
    inc dword [vehicles_served]
    call append_receipt_txt
    call append_csv
    mov ebx, [b_slot]
    mov esi, e_out                     ; write the departure into parked_vehicles.txt
    mov eax, [b_exit]
    call log_parked
    mov ebx, [b_slot]
    mov byte [slot_used+ebx], 0
.done:
    popad
    ret

; --------------------------------------------------------------------------
;  Receipt printing (same code writes to the screen or to a file)
; --------------------------------------------------------------------------
print_bill:
    pushad
    COLOR c_peach
    PRINT r_top
    COLOR c_reset
    PRINT v_plate
    COLOR c_honey
    mov ebx, [b_slot]
    call plate_addr
    call print_str
    COLOR c_reset
    PRINT nl
    PRINT v_name
    call name_addr
    call print_str
    PRINT nl
    PRINT v_type
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov esi, [type_names+eax*4]
    call print_str
    PRINT nl
    PRINT v_entry
    mov eax, [tmp_entry]
    call print_time
    PRINT nl
    PRINT r_exit
    mov eax, [b_exit]
    call print_time
    PRINT nl
    PRINT r_dur
    NUM b_dur
    PRINT r_min
    PRINT r_hours
    NUM b_hours
    PRINT nl
    PRINT r_rate
    NUM b_rate
    PRINT nl
    PRINT r_gross
    NUM b_gross
    PRINT nl
    cmp dword [b_capped], 1
    jne .nocap
    COLOR c_honey
    PRINT m_cap
    COLOR c_reset
.nocap:
    PRINT r_disc
    NUM b_disc
    PRINT nl
    COLOR c_olive
    PRINT r_total
    NUM b_net
    PRINT nl
    COLOR c_reset
    popad
    ret

print_payment:
    pushad
    cmp dword [b_net], 0
    jne .paid
    COLOR c_olive
    PRINT m_free_exit
    COLOR c_reset
    jmp .end
.paid:
    PRINT r_paid
    NUM b_paid
    PRINT nl
    COLOR c_honey
    PRINT r_change
    NUM b_change
    PRINT nl
    COLOR c_reset
    cmp dword [b_change], 0
    je  .end
    PRINT r_given
    mov eax, [b_change]
    call print_breakdown
.end:
    COLOR c_peach
    PRINT r_bottom
    COLOR c_reset
    popad
    ret

print_breakdown:                       ; eax = change, loops over denominations
    pushad
    mov ebx, eax
    xor esi, esi
.d:
    cmp esi, 5
    jae .end
    mov eax, ebx
    xor edx, edx
    mov ecx, [denoms+esi*4]
    div ecx                            ; DIV: eax = notes, edx = remainder
    mov ebx, edx
    test eax, eax
    jz  .skip
    push eax
    PRINT r_note1
    mov eax, [denoms+esi*4]
    call print_num
    PRINT r_note2
    pop eax
    call print_num
    PRINT nl
.skip:
    inc esi
    jmp .d
.end:
    popad
    ret

; ==========================================================================
;  DAILY SUMMARY
; ==========================================================================
show_summary:
    pushad
    COLOR c_peach
    PRINT s_head
    COLOR c_reset
    call count_occupied
    mov [tmp_occ], eax
    PRINT s_occ
    NUM tmp_occ
    PRINT nl
    PRINT s_free
    mov eax, MAXSLOTS
    sub eax, [tmp_occ]                 ; SUB: free = total - occupied
    call print_num
    PRINT nl
    PRINT s_pct
    mov eax, [tmp_occ]
    mov ecx, 100
    mul ecx                            ; MUL: occupied x 100
    xor edx, edx
    mov ecx, MAXSLOTS
    div ecx                            ; DIV: percentage
    call print_num
    PRINT s_pct2
    PRINT s_bar
    mov ecx, [tmp_occ]
    COLOR c_coral
.b1:
    test ecx, ecx
    jz  .b1done
    CHAR '#'
    dec ecx
    jmp .b1
.b1done:
    COLOR c_olive
    mov ecx, MAXSLOTS
    sub ecx, [tmp_occ]
.b2:
    test ecx, ecx
    jz  .b2done
    CHAR '-'
    dec ecx
    jmp .b2
.b2done:
    COLOR c_reset
    PRINT s_barend
    COLOR c_honey
    PRINT s_rev
    NUM total_revenue
    PRINT nl
    COLOR c_reset
    PRINT s_served
    NUM vehicles_served
    PRINT nl
    PRINT s_avg
    cmp dword [vehicles_served], 0
    jne .avg
    CHAR '0'
    jmp .avgdone
.avg:
    mov eax, [total_revenue]
    xor edx, edx
    div dword [vehicles_served]        ; DIV: average fee
    call print_num
.avgdone:
    PRINT nl
    COLOR c_peach
    PRINT s_bottom
    COLOR c_reset
    popad
    ret

; ==========================================================================
;  MENU SCREEN
; ==========================================================================
draw_menu:
    pushad
    COLOR c_clear
    COLOR c_clear2
    COLOR c_banner
    PRINT m_t1
    PRINT m_t2
    PRINT m_t3
    COLOR c_reset
    PRINT nl
    COLOR c_honey
    PRINT m_menu1
    PRINT m_menu2
    PRINT m_menu3
    PRINT m_menu4
    PRINT m_menu5
    COLOR c_honey
    PRINT m_menu6
    PRINT m_menu7
    COLOR c_coral
    PRINT m_menu8
    COLOR c_reset
    PRINT nl
    COLOR c_honey
    PRINT m_status
    call count_occupied
    call print_num
    PRINT m_of
    mov eax, MAXSLOTS
    call print_num
    PRINT m_occ
    COLOR c_reset
    popad
    ret

; ==========================================================================
;  FILE HANDLING  (sys_open / sys_write / sys_close, TXT + CSV)
; ==========================================================================
open_append:                           ; esi = file name -> eax = fd (<0 = error)
    push ebx
    push ecx
    push edx
    mov ebx, esi
    mov ecx, 0x441                     ; O_WRONLY | O_CREAT | O_APPEND
    mov edx, 0x1A4                     ; permissions 0644
    mov eax, 5                         ; sys_open
    int 0x80
    pop edx
    pop ecx
    pop ebx
    ret

open_trunc:                            ; esi = file name -> eax = fd (<0 = error)
    push ebx
    push ecx
    push edx
    mov ebx, esi
    mov ecx, 0x241                     ; O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0x1A4
    mov eax, 5
    int 0x80
    pop edx
    pop ecx
    pop ebx
    ret

close_fd:                              ; ebx = fd
    push eax
    mov eax, 6                         ; sys_close
    int 0x80
    pop eax
    ret

file_error:
    COLOR c_coral
    PRINT m_fileerr
    COLOR c_reset
    ret

append_receipt_txt:                    ; adds the receipt to receipts.txt
    pushad
    mov esi, f_receipts
    call open_append
    test eax, eax
    js  .err
    mov [fd_tmp], eax
    push dword [out_fd]
    mov [out_fd], eax
    call print_bill
    call print_payment
    mov ebx, [fd_tmp]
    call close_fd
    pop dword [out_fd]
    jmp .done
.err:
    call file_error
.done:
    popad
    ret

append_csv:                            ; adds one row to transactions.csv
    pushad
    mov esi, f_trans_csv
    call open_append
    test eax, eax
    js  .err
    mov [fd_tmp], eax
    mov ebx, eax                       ; file empty? then write the header
    mov eax, 19                        ; sys_lseek(fd, 0, SEEK_END)
    xor ecx, ecx
    mov edx, 2
    int 0x80
    mov [tmp_size], eax
    push dword [out_fd]
    mov eax, [fd_tmp]
    mov [out_fd], eax
    cmp dword [tmp_size], 0
    jne .row
    PRINT h_csv_trans
.row:
    mov ebx, [b_slot]
    call plate_addr
    call print_str
    CHAR ','
    call name_addr
    call print_str
    CHAR ','
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov esi, [type_names+eax*4]
    call print_str
    CHAR ','
    mov eax, [tmp_entry]
    call print_time
    CHAR ','
    mov eax, [b_exit]
    call print_time
    CHAR ','
    NUM b_dur
    CHAR ','
    NUM b_hours
    CHAR ','
    NUM b_rate
    CHAR ','
    NUM b_gross
    CHAR ','
    NUM b_disc
    CHAR ','
    NUM b_net
    CHAR ','
    NUM b_paid
    CHAR ','
    NUM b_change
    PRINT nl
    mov ebx, [fd_tmp]
    call close_fd
    pop dword [out_fd]
    jmp .done
.err:
    call file_error
.done:
    popad
    ret

log_parked:                            ; esi = event text, ebx = slot, eax = time (minutes)
    pushad                             ; adds one line to parked_vehicles.txt
    mov [tmp_logtime], eax
    mov [tmp_logevt], esi
    mov esi, f_parked
    call open_append
    test eax, eax
    js  .err
    mov [fd_tmp], eax
    mov [tmp_slot2], ebx               ; keep the slot index (lseek overwrites registers)
    mov ebx, eax
    mov eax, 19                        ; sys_lseek(fd, 0, SEEK_END): new file? write heading
    xor ecx, ecx
    mov edx, 2
    int 0x80
    mov [tmp_size], eax
    mov ebx, [tmp_slot2]
    push dword [out_fd]
    mov eax, [fd_tmp]
    mov [out_fd], eax
    cmp dword [tmp_size], 0
    jne .row
    PRINT h_parked1
    PRINT h_parked2
    PRINT h_parked3
.row:
    mov esi, [tmp_logevt]
    call print_str
    CHAR '|'
    CHAR ' '
    mov eax, ebx
    inc eax
    call print_num2
    CHAR ' '
    CHAR ' '
    CHAR ' '
    CHAR '|'
    CHAR ' '
    call plate_addr
    mov ecx, 8
    call print_str_pad
    CHAR ' '
    CHAR '|'
    CHAR ' '
    call name_addr
    mov ecx, 20
    call print_str_pad
    CHAR ' '
    CHAR '|'
    CHAR ' '
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov esi, [type_names+eax*4]
    mov ecx, 10
    call print_str_pad
    CHAR ' '
    CHAR '|'
    CHAR ' '
    mov eax, [tmp_logtime]
    call print_time
    PRINT nl
    mov ebx, [fd_tmp]
    call close_fd
    pop dword [out_fd]
    jmp .done
.err:
    call file_error
.done:
    popad
    ret

save_reports:                          ; writes parking_status.txt and .csv
    pushad
    ; ---- TXT report (re-uses the screen routines, colours are skipped) ----
    mov esi, f_status_txt
    call open_trunc
    test eax, eax
    js  .err
    mov [fd_tmp], eax
    push dword [out_fd]
    mov [out_fd], eax
    PRINT h_txt
    PRINT nl
    call view_lot
    call show_summary
    mov ebx, [fd_tmp]
    call close_fd
    pop dword [out_fd]

    ; ---- CSV report -----------------------------------------------------------
    mov esi, f_status_csv
    call open_trunc
    test eax, eax
    js  .err
    mov [fd_tmp], eax
    push dword [out_fd]
    mov [out_fd], eax
    PRINT h_csv_status
    xor ebx, ebx
.r:
    cmp ebx, MAXSLOTS
    jae .closed
    mov eax, ebx
    inc eax
    call print_num
    CHAR ','
    cmp byte [slot_used+ebx], 1
    jne .free
    PRINT s_occ_csv
    CHAR ','
    call plate_addr
    call print_str
    CHAR ','
    call name_addr
    call print_str
    CHAR ','
    movzx eax, byte [slot_type+ebx]
    dec eax
    mov esi, [type_names+eax*4]
    call print_str
    CHAR ','
    movzx eax, word [slot_entry+ebx*2]
    call print_time
    jmp .nl
.free:
    PRINT s_free_csv
.nl:
    PRINT nl
    inc ebx
    jmp .r
.closed:
    mov ebx, [fd_tmp]
    call close_fd
    pop dword [out_fd]
    COLOR c_olive
    PRINT m_saved1
    PRINT m_saved2
    COLOR c_reset
    jmp .done
.err:
    call file_error
.done:
    popad
    ret
