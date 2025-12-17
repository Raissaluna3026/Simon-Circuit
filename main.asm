.nolist
.include "m328Pdef.inc"
.list

.def SEQ_SEL  = r15
.def CURR_LEN = r16
.def SEQ_IDX  = r17
.def BTN_VAL  = r18
.def BTN_FLAG = r19
.def TEMP     = r20
.def EXPECT   = r21
.equ indicador = pd3

.cseg
; endereco onde o codigo comeca, assim que ele o atmega inicia ele vai jumpar para reset pois la temos as configuracoes
.org 0x0000 
    rjmp RESET

;como atmega tem tabela fixa de vetores, pcint0 e o que esta no endereco 0x0006 e é ele que usamos pois
;é equivalent aos pbs, que utilizamos nas interrupcoes

.org 0x0006 
    rjmp PCINT0_ISR


;Tabela com a sequencia que os leds piscam, a cada erro ele passa para a proxima sequencia,
;isso foi feito para simular aleatoriedade.

SEQ_TABLE: 
    .db 0,0,2,1,1,1,0,0,3,0,0,0,1,1,0,1
    .db 3,1,3,2,0,1,3,2,2,1,1,2,0,0,3,0
    .db 2,2,2,0,3,0,3,0,2,2,1,0,0,1,2,0
    .db 1,0,3,2,3,2,1,2,2,1,2,0,1,1,1,3
    .db 3,2,1,2,0,1,0,2,3,2,0,1,2,1,3,3
    .db 3,1,2,1,1,2,3,3,2,1,1,3,0,0,0,1
    .db 1,3,0,3,3,3,2,0,0,2,2,0,2,3,1,3
    .db 0,2,1,0,2,1,1,2,1,0,2,3,0,0,2,2
    .db 1,0,1,0,0,3,0,1,1,3,1,2,3,1,1,2
    .db 3,2,3,3,0,1,1,0,2,0,1,1,0,0,0,1
    .db 0,0,2,0,1,2,3,1,1,3,1,3,3,1,0,0
    .db 3,2,3,3,3,0,0,0,3,2,0,1,1,1,3,1
    .db 3,1,2,3,1,0,3,0,0,0,0,1,1,3,3,3
    .db 1,3,0,1,3,0,3,2,3,2,3,3,1,1,2,1
    .db 0,0,2,0,0,3,1,0,0,1,0,0,1,3,0,1

RESET:
	;Configuracao da memoria ram para funcionar de maneira correta
    ldi TEMP, low(RAMEND)
    out SPL, TEMP
    ldi TEMP, high(RAMEND)
    out SPH, TEMP 

	;Configurando porta dos leds
    ldi TEMP, 0b11111000 
    out DDRD, TEMP
    clr TEMP
    out PORTD, TEMP 

	;Configurando inputs e ativando pull up
    ldi TEMP, 0x00
    out DDRB, TEMP
    ldi TEMP, 0x0F
    out PORTB, TEMP
	 
	;Ativando grupo pcint0 que sera utilizado nas interrupcoes
    ldi TEMP, (1<<PCIE0)
    sts PCICR, TEMP
	;;Ativando as que utilizaremos na interrupcoes dos botoes
    ldi TEMP, (1<<PCINT0)|(1<<PCINT1)|(1<<PCINT2)|(1<<PCINT3)
    sts PCMSK0, TEMP 

    clr BTN_FLAG
    clr SEQ_SEL
    ldi CURR_LEN, 1 ; indica tamanho da primeira sequencia, comecamos com 1

    sei ; ativa interrupcao global, sem ela nenhuma interrupcao funcionaria

StartGame:
    clr BTN_FLAG
    clr SEQ_IDX
    ldi CURR_LEN, 1 ; indica tamanho da primeira sequencia, comecamos com 1

GameLoop:
    rcall ShowSequence ;; Mostro a sequencia
    rcall ReadPlayerSequence ;; Leio a sequencia

	;se chegou aqui o jogador acertou a sequecia
	sbi PORTD, indicador ;;funcionamento do led indicador 
	rcall DelayLong
	cbi PORTD, indicador
	rcall DelayLong

    inc CURR_LEN
    cpi CURR_LEN, 17 ;; O programa acaba quando acertamos os 16 leds seguidos
					 ;; Se ainda nao temos isso, voltamos pro loop
    brlt GameLoop

    rcall WinAnimation ;; mostra animacao da vitoria
    rcall NextSequence ;; carrega a proxima sequencia
    rjmp StartGame ;;reinicia o jogo

NextSequence:
    inc SEQ_SEL
    mov TEMP, SEQ_SEL
    cpi TEMP, 15
    brlt NextSeqNoWrap
    clr SEQ_SEL
NextSeqNoWrap:
    ret

	;;Isso faz Z apontar pro inicio da sequencia atual
SetZToCurrentSeqBase:
	;;Fazemos 4 bit shift left pois isso equivale a multiplicar por 16
	;;Como cada sequencia possui 16 bytes, fazemos isso para sempre mudar
	;;para a proxima sequencia com base em seq_sel que mostra o numero da sequencia que estamos
    mov TEMP, SEQ_SEL 
    lsl TEMP
    lsl TEMP
    lsl TEMP
    lsl TEMP 

	;;leio a tabela
    ldi ZL, low(SEQ_TABLE*2)
    ldi ZH, high(SEQ_TABLE*2) 

    rcall AddTempToZ
    ret

ShowSequence:
    clr SEQ_IDX ;; aponta Z para o inicio da sequencia atual, indica qual passo da sequencia estou mostrando
    rcall SetZToCurrentSeqBase ;; aponto para a sequencia correta dentre as 15

ShowSeqLoop: ;; label para mostrar cada led
    cp SEQ_IDX, CURR_LEN ;; Verifico se ja foram mostrados todos os passos da sequencia, se sim, saio da rotina
    brge ShowSeqDone

    lpm BTN_VAL, Z+ ; o byte em Z vai para BTN_val e Z incrementa 1 unidade.
    rcall FlashLedIndex ;; pisque o led correspondente

    inc SEQ_IDX ;; aumenta 1 para mostrar proximo led
    rjmp ShowSeqLoop

ShowSeqDone:
    ret ;; saio da rotina

ReadPlayerSequence: ;; espera jogador aperta botao, se acertar
					;; piscamos como feedback e vamos pro proximo passo
					;; se errar vamos para wrong_answer
    clr SEQ_IDX

WaitPress:
    tst BTN_FLAG ;; fico preso nesse loop ate achar um botao para processar
    breq WaitPress

    clr BTN_FLAG ;; "apago o botao"

    rcall SetZToCurrentSeqBase ;; Aponto Z apontar para a sequencia o começo da sequencia altuta
    mov TEMP, SEQ_IDX 
    rcall AddTempToZ ;; soma o SEQ_IDX em z para ir para o led correto
    lpm EXPECT, Z ;; lemos o led

    cp BTN_VAL, EXPECT ;; comparamos se o esperado é igual o pressionado
    brne WrongAnswer ;; se for diferente vamos pra wrong_answer

    rcall FlashLedIndex ;; se for certo, piscamos o led

    inc SEQ_IDX ;; aumentamos 1 na sequencia
    cp SEQ_IDX, CURR_LEN ;; se a sequencia nao foi toda preenchida, volta pro loop
    brlt WaitPress

    ret ;; se ja acabou retornamos

WrongAnswer:
	;;Se for errado eu mostro animacao de derroto e comeco de novo
    rcall LoseAnimation
    rcall NextSequence
    rjmp StartGame

AddTempToZ:
    push r22 ; guardo o registrator r22 para nao perdemos o conteudo
    mov  r22, TEMP ;coloco o temp em r22, vao utilizar como contador
AddLoop:
    tst  r22 ;; testa se isso é 0
    breq AddDone ;; se é zero, é já fizemos todas as somas e vamos para addDone
    adiw ZL, 1 ;; Adiciono 1 no ponteiro Z
    dec  r22 ; Diminuo o contador
    rjmp AddLoop ;; Volto pro loop
AddDone:
    pop  r22 ; retiro o conteudo original de r22
    ret

FlashLedIndex:
    push r22 ;; vamos colocar na pilha para não perder o valor
    ldi TEMP, 0x10 ;; colocamos como padrao no led 0 (pd4) e vamos usar como mascara
    mov r22, BTN_VAL ;; copio o indice de BTN_VAL para saber quantos bit shifts serão necessários

ShiftLoop:
    tst r22 ;; testo se é 0, se for, nao precisamos fazer nada e vamos para Shift
    breq ShiftDone
    lsl TEMP ;; se nao for, fazemos bitshift left o suficiente para ir para o led correto
    dec r22
    rjmp ShiftLoop

ShiftDone:
    out PORTD, TEMP ;; depois de estar no LED certo, acendemos
    rcall DelayLong
    clr TEMP
    out PORTD, TEMP ;; apagamos o led
    rcall DelayLong

    pop r22 ;; retiramos o valor salvo
    ret ;; retornamos

LoseAnimation:
    cli ;; desliga interrupcoes globais
    clr BTN_FLAG ;; da clear no BTN_flag para que nao exista botao pendente

    ldi r23, 5 ;; representa quantas vezes o led vai piscar para representar o erro
ErrLoop: ;; loop do erro
    ldi TEMP, 0b11110000
    out PORTD, TEMP
    rcall DelayLong

    clr TEMP
    out PORTD, TEMP
    rcall DelayLong

    dec r23
    brne ErrLoop

WaitAllReleased: ;; impedir que o jogo reinicie enquanto todos botoes nao estiverem sotos
    in TEMP, PINB
    andi TEMP, 0x0F
    cpi TEMP, 0x0F
    brne WaitAllReleased

    rcall DelayLong

    ldi TEMP, (1<<PCIF0) ;; limpar flag de interrupcoes
    sts PCIFR, TEMP

    clr BTN_FLAG ;; clear na flag
    sei ;; ativo interrupcoes
    ret ;; retorno


	;;Animacao da vitoria, quando o player zerar uma sequencia
WinAnimation:
    cli
    clr BTN_FLAG 

    ldi r23, 10
WinLoop:
    ldi TEMP, 0b10100000
    out PORTD, TEMP
    rcall DelayLong

    ldi TEMP, 0b01010000
    out PORTD, TEMP
    rcall DelayLong

    dec r23
    brne WinLoop

    clr TEMP
    out PORTD, TEMP

WaitWinRelease:
	;;Isso serve para garantir que todos os botoes estao soltos antes de voltar pro jogo
	;;Se não tiverem ficam em um loop
    in TEMP, PINB
    andi TEMP, 0x0F
    cpi TEMP, 0x0F
    brne WaitWinRelease

    rcall DelayLong
	;; Limpamos a flag porque algum botao pode ter sido apertado durante a animacao
	;; Isso fica numa especie de fila e daria errado quando voltassemos para o jogo
	;;Limpamos ela escrevendo 1
    ldi TEMP, (1<<PCIF0) 
    sts PCIFR, TEMP
    clr BTN_FLAG ;; isso e para garantir que o programa nao vai achar nenhuma entrada velha
    sei ;; habilito interrupcoes globais
    ret

	;; Utilizado apenas como delay
DelayLong:
    ldi r24, 40
DL1:
    ldi r25, 255
DL2:
    ldi r22, 255
DL3:
    dec r22
    brne DL3
    dec r25
    brne DL2
    dec r24
    brne DL1
    ret

	;; Salvamos os registradores que vamos utilizar para reveter depois
	;; Pois podemos mexer neles durante a ISR e perder os dados.
PCINT0_ISR: 
    push r20
    push r22
    in   r20, SREG
    push r20
    ldi  r22, 150
DbLoop: 
    dec  r22
    brne DbLoop ;Representa um pequeno atraso

    in   r20, PINB ;; Leio os botoes
    com  r20 ;; inverto os botoes
    andi r20, 0x0F ;; se todos ficaram 0, nenhum botao foi pressionado, sai normal pro noPressISR
    breq NoPressISR
	
	;;Se nem todos ficaram 0, algum foi pressionado, precisamos saber qual e vamos testar 1 por 1
	;;Testamos botao por botao e dependendo de qual for tomamos medidas diferentes
    cpi  r20, 1
    breq Btn0
    cpi  r20, 2
    breq Btn1
    cpi  r20, 4
    breq Btn2
    cpi  r20, 8
    breq Btn3
    rjmp NoPressISR ; Se nenhum botao foi pressionado, tambem vamos para noPressISR

	;Fazemos isso para saber qual botao foi pressionado e salvamos ele em BTN_VAL
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
    ldi BTN_FLAG, 1 ;; Sinal pro programa principal para significar de que de fato
					;; achamos um botao que foi pressionado

NoPressISR:
    pop  r20
    out  SREG, r20
    pop  r22
    pop  r20
    reti ; Retira informações salvas na pilha e volta para o programa normalmente