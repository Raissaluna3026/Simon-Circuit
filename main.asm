.nolist
.include "m328Pdef.inc"
.list

; -------------------------------------
; Definição de registradores
; -------------------------------------
.def SEQ_SEL  = r15    ; qual sequência (0..14)
.def CURR_LEN = r16    ; tamanho atual da sequência (1..16)
.def SEQ_IDX  = r17    ; índice dentro da sequência (0..15)
.def BTN_VAL  = r18    ; botão pressionado (0..3)
.def BTN_FLAG = r19    ; 0 = sem tecla, 1 = tecla disponível
.def TEMP     = r20    ; uso geral
.def EXPECT   = r21    ; valor esperado da sequência
.equ indicador = PD3   ; indicador de acerto de sequencia

; -------------------------------------
; Vetores de interrupção (endereços em bytes)
; -------------------------------------
.cseg
.org 0x0000
    rjmp RESET          ; Reset

.org 0x0006             ; PCINT0 (PB0..PB7)
    rjmp PCINT0_ISR

; -------------------------------------
; TABELA DE 15 SEQUÊNCIAS, CADA UMA COM 16 PASSOS (0..3)
; 0..3 → LED/botão: 0=PD4/PB0, 1=PD5/PB1, 2=PD6/PB2, 3=PD7/PB3
; -------------------------------------
SEQ_TABLE:
; sequência 0
    .db 0,0,2,1,1,1,0,0,3,0,0,0,1,1,0,1
; sequência 1
    .db 3,1,3,2,0,1,3,2,2,1,1,2,0,0,3,0
; sequência 2
    .db 2,2,2,0,3,0,3,0,2,2,1,0,0,1,2,0
; sequência 3
    .db 1,0,3,2,3,2,1,2,2,1,2,0,1,1,1,3
; sequência 4
    .db 3,2,1,2,0,1,0,2,3,2,0,1,2,1,3,3
; sequência 5
    .db 3,1,2,1,1,2,3,3,2,1,1,3,0,0,0,1
; sequência 6
    .db 1,3,0,3,3,3,2,0,0,2,2,0,2,3,1,3
; sequência 7
    .db 0,2,1,0,2,1,1,2,1,0,2,3,0,0,2,2
; sequência 8
    .db 1,0,1,0,0,3,0,1,1,3,1,2,3,1,1,2
; sequência 9
    .db 3,2,3,3,0,1,1,0,2,0,1,1,0,0,0,1
; sequência 10
    .db 0,0,2,0,1,2,3,1,1,3,1,3,3,1,0,0
; sequência 11
    .db 3,2,3,3,3,0,0,0,3,2,0,1,1,1,3,1
; sequência 12
    .db 3,1,2,3,1,0,3,0,0,0,0,1,1,3,3,3
; sequência 13
    .db 1,3,0,1,3,0,3,2,3,2,3,3,1,1,2,1
; sequência 14
    .db 0,0,2,0,0,3,1,0,0,1,0,0,1,3,0,1

; =====================================
; INICIALIZAÇÃO
; =====================================
RESET:
    ; Stack
    ldi TEMP, low(RAMEND)
    out SPL, TEMP
    ldi TEMP, high(RAMEND)
    out SPH, TEMP

    ; LEDs em PD4..PD7 como saída
    ldi TEMP, 0b11111000 ; coloquei um 1, antes era ob1111000
    out DDRD, TEMP
    clr TEMP
    out PORTD, TEMP      ; todos LEDs apagados


    ; Botões PB0..PB3 como entrada com pull-up
    ldi TEMP, 0x00
    out DDRB, TEMP       ; tudo entrada
    ldi TEMP, 0x0F
    out PORTB, TEMP      ; pull-up em PB0..PB3

    ; Habilita interrupção de Pin Change 0
    ldi TEMP, (1<<PCIE0)
    sts PCICR, TEMP
    ldi TEMP, (1<<PCINT0)|(1<<PCINT1)|(1<<PCINT2)|(1<<PCINT3)
    sts PCMSK0, TEMP

    clr BTN_FLAG
    clr SEQ_SEL          ; começa na sequência 0
    ldi CURR_LEN, 1      ; começa com tamanho 1

    sei                  ; habilita interrupções globais

; =====================================
; LOOP PRINCIPAL
; =====================================
StartGame:
    clr BTN_FLAG
    clr SEQ_IDX
    ldi CURR_LEN, 1      ; sempre recomeça da sequência com tamanho 1

GameLoop:
    rcall ShowSequence
    rcall ReadPlayerSequence
	

    ; Se chegou aqui, acertou a rodada

	; --- BLOCO DO LED INDICADOR ---
    sbi PORTD, indicador   ; Liga o LED indicador (PD3)
    rcall DelayLong        ; Espera um tempo com ele ligado
    cbi PORTD, indicador   ; Desliga o LED
    rcall DelayLong        ; Pequena pausa antes de mostrar a nova sequência
    ; ------------------------------
    inc CURR_LEN
    cpi CURR_LEN, 17
    brlt GameLoop        ; se ainda não chegou em 16, próxima rodada

    ; Acertou os 16 passos → vitória, depois próxima sequência
    rcall WinAnimation
    rcall NextSequence
    rjmp StartGame

; =====================================
; AVANÇAR PARA A PRÓXIMA SEQUÊNCIA (0..14, cíclico)
; =====================================
NextSequence:
    inc SEQ_SEL
    mov TEMP, SEQ_SEL
	cpi TEMP, 15
	brlt NextSeqNoWrap
	clr SEQ_SEL
         ; se passou de 14, volta para 0
NextSeqNoWrap:
    ret

; =====================================
; AJUSTA Z PARA O INÍCIO DA SEQUÊNCIA ATUAL
; Z = &SEQ_TABLE[SEQ_SEL * 16]
; =====================================
SetZToCurrentSeqBase:
    ; TEMP = SEQ_SEL * 16 (shift 4 vezes)
    mov TEMP, SEQ_SEL
    lsl TEMP
    lsl TEMP
    lsl TEMP
    lsl TEMP              ; TEMP = SEQ_SEL * 16 (0..224)

    ; Z = endereço base da tabela (em bytes)
    ldi ZL, low(SEQ_TABLE*2)
    ldi ZH, high(SEQ_TABLE*2)

    ; soma TEMP em Z (byte a byte)
    rcall AddTempToZ
    ret

; =====================================
; MOSTRAR SEQUÊNCIA (1..CURR_LEN)
; =====================================
ShowSequence:
    clr SEQ_IDX
    rcall SetZToCurrentSeqBase   ; Z = início da sequência atual

ShowSeqLoop:
	rcall DelayLong
    cp SEQ_IDX, CURR_LEN
    brge ShowSeqDone

    lpm BTN_VAL, Z+              ; lê próximo passo (0..3)
    rcall FlashLedIndex

    inc SEQ_IDX
    rjmp ShowSeqLoop

ShowSeqDone:
    ret

; =====================================
; LER SEQUÊNCIA DO JOGADOR
; =====================================
ReadPlayerSequence:
    clr SEQ_IDX

WaitPress:
    tst BTN_FLAG
    breq WaitPress        ; espera botão (flag setada na ISR)

    clr BTN_FLAG          ; consome tecla

    ; EXPECT = passo da sequência em SEQ_IDX
    rcall SetZToCurrentSeqBase   ; Z = base
    mov TEMP, SEQ_IDX
    rcall AddTempToZ            ; Z += SEQ_IDX
    lpm EXPECT, Z

    cp BTN_VAL, EXPECT
    brne WrongAnswer            ; se diferente → errou

    ; acerto → pisca LED correspondente
    rcall FlashLedIndex

    inc SEQ_IDX
    cp SEQ_IDX, CURR_LEN
    brlt WaitPress              ; ainda faltam passos

    ; acertou a rodada toda
    ret

WrongAnswer:
    ; Erro → anima, avança seq., recomeça
    rcall LoseAnimation
    rcall NextSequence
    rjmp StartGame

; =====================================
; Soma TEMP ao ponteiro Z (TEMP bytes)
; =====================================
AddTempToZ:
    push r22
    mov  r22, TEMP
AddLoop:
    tst  r22
    breq AddDone
    adiw ZL, 1
    dec  r22
    rjmp AddLoop
AddDone:
    pop  r22
    ret

; =====================================
; PISCA LED (BTN_VAL = 0..3 → PD4..PD7)
; =====================================
FlashLedIndex:
    push r22
    ldi TEMP, 0x10       ; PD4
    mov r22, BTN_VAL

ShiftLoop:
    tst r22
    breq ShiftDone
    lsl TEMP
    dec r22
    rjmp ShiftLoop

ShiftDone:
    out PORTD, TEMP
    rcall DelayLong
    clr TEMP
    out PORTD, TEMP
    rcall DelayLong

    pop r22
    ret

; =====================================
; ANIMAÇÃO DE ERRO
; =====================================
LoseAnimation:
    cli
    clr BTN_FLAG

    ldi r23, 3           ; 3 piscadas
ErrLoop:
    ldi TEMP, 0b11110000 ; todos LEDs
    out PORTD, TEMP
    rcall DelayLong

    clr TEMP
    out PORTD, TEMP
    rcall DelayLong

    dec r23
    brne ErrLoop

    ; Espera todos os botões soltos
WaitAllReleased:
    in TEMP, PINB
    andi TEMP, 0x0F
    cpi TEMP, 0x0F       ; 1111 = todos soltos
    brne WaitAllReleased

    rcall DelayLong

    ; limpa flag de PCINT pendente
    ldi TEMP, (1<<PCIF0)
    sts PCIFR, TEMP

    clr BTN_FLAG
    sei
    ret

; =====================================
; ANIMAÇÃO DE VITÓRIA (diferente)
; =====================================
WinAnimation:
    cli
    clr BTN_FLAG

    ldi r23, 6           ; 6 ciclos de padrão
WinLoop:
    ; padrão alternado 1
    ldi TEMP, 0b10100000 ; PD7 e PD5
    out PORTD, TEMP
    rcall DelayLong

    ; padrão alternado 2
    ldi TEMP, 0b01010000 ; PD6 e PD4
    out PORTD, TEMP
    rcall DelayLong

    dec r23
    brne WinLoop

    clr TEMP
    out PORTD, TEMP

    ; também espera soltar botões (por segurança)
WaitWinRelease:
    in TEMP, PINB
    andi TEMP, 0x0F
    cpi TEMP, 0x0F
    brne WaitWinRelease

    rcall DelayLong
    ldi TEMP, (1<<PCIF0)
    sts PCIFR, TEMP
    clr BTN_FLAG
    sei
    ret

; =====================================
; DELAY SIMPLES (NÃO USA r23)
; =====================================
DelayLong:
    ldi r24, 40          ; ajuste esse valor para mais/menos tempo
DL1:
    ldi r25, 255
DL2:
    ldi r22, 255         ; usar r22 em vez de r26
DL3:
    dec r22
    brne DL3
    dec r25
    brne DL2
    dec r24
    brne DL1
    ret


; =====================================
; ISR DE PCINT0 (PB0..PB3 → BOTÕES)
; =====================================
PCINT0_ISR:
    push r20
    push r22
    in   r20, SREG
    push r20

    ; debounce simples
    ldi  r22, 150
DbLoop:
    dec  r22
    brne DbLoop

    in   r20, PINB
    com  r20            ; invertido: pressionado=1 (pull-up)
    andi r20, 0x0F      ; só PB0..PB3
    breq NoPressISR

    cpi  r20, 1
    breq Btn0
    cpi  r20, 2
    breq Btn1
    cpi  r20, 4
    breq Btn2
    cpi  r20, 8
    breq Btn3
    rjmp NoPressISR     ; se mais de um botão → ignora

Btn0:
    ldi BTN_VAL, 0
    rjmp SetISR
Btn1:
    ldi BTN_VAL, 1
    rjmp SetISR
Btn2:
    ldi BTN_VAL, 2
    rjmp SetISR
Btn3:
    ldi BTN_VAL, 3

SetISR:
    ldi BTN_FLAG, 1

NoPressISR:
    pop  r20
    out  SREG, r20
    pop  r22
    pop  r20
    reti
