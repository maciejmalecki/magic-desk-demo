
#import "_md-loader.asm"

.label LOADER_START = $A00 // covertopt

.label zTonyBase = $B0
.label COUNTER                  = zTonyBase         // 2 bytes $02
.label SOURCE_PTR               = zTonyBase + 5     //$07         // $07, $08 2 bytes
.label DEST_PTR                 = zTonyBase + 7     //$0F           // $0F, $10 2 bytes

// START: from c64lib library

/*
 * MOS6510 Registers.
 */
.label MOS_6510_DIRECTION       = $00
.label MOS_6510_IO              = $01

/*
 * I/O Register bits.
 */
.label CASETTE_MOTOR_OFF        = %00100000
.label CASETTE_SWITCH_CLOSED    = %00010000
.label CASETTE_DATA             = %00001000
.label PLA_CHAREN               = %00000100
.label PLA_HIRAM                = %00000010
.label PLA_LORAM                = %00000001

/*
 * Possible I/O & PLA configurations.
 */
.label RAM_RAM_RAM              = %000
.label RAM_CHAR_RAM             = PLA_LORAM
.label RAM_CHAR_KERNAL          = PLA_HIRAM
.label BASIC_CHAR_KERNAL        = PLA_LORAM | PLA_HIRAM
.label RAM_IO_RAM               = PLA_CHAREN | PLA_LORAM
.label RAM_IO_KERNAL            = PLA_CHAREN | PLA_HIRAM
.label BASIC_IO_KERNAL          = PLA_CHAREN | PLA_LORAM | PLA_HIRAM

// CIA1
.label CIA1               = $DC00 
.label CIA1_DATA_PORT_A   = CIA1 + $00
.label CIA1_DATA_PORT_B   = CIA1 + $01
.label CIA1_DATA_DIR_A    = CIA1 + $02
.label CIA1_DATA_DIR_B    = CIA1 + $03
.label CIA1_TIMER_A_LO    = CIA1 + $04 
.label CIA1_TIMER_A_HI    = CIA1 + $05 
.label CIA1_TIMER_B_LO    = CIA1 + $06 
.label CIA1_TIMER_B_HI    = CIA1 + $07 
.label CIA1_TOD_SEC10     = CIA1 + $08 
.label CIA1_TOD_SEC       = CIA1 + $09
.label CIA1_TOD_MIN       = CIA1 + $0A
.label CIA1_TOD_HOUR      = CIA1 + $0B
.label CIA1_IO_BUFFER     = CIA1 + $0C
.label CIA1_IRQ_CONTROL   = CIA1 + $0D
.label CIA1_CONTROL_A     = CIA1 + $0E
.label CIA1_CONTROL_B     = CIA1 + $0F

// CIA2
.label CIA2               = $DD00
.label CIA2_DATA_PORT_A   = CIA2 + $00
.label CIA2_DATA_PORT_B   = CIA2 + $01
.label CIA2_DATA_DIR_A    = CIA2 + $02
.label CIA2_DATA_DIR_B    = CIA2 + $03
.label CIA2_TIMER_A_LO    = CIA2 + $04 
.label CIA2_TIMER_A_HI    = CIA2 + $05 
.label CIA2_TIMER_B_LO    = CIA2 + $06 
.label CIA2_TIMER_B_HI    = CIA2 + $07 
.label CIA2_TOD_SEC10     = CIA2 + $08 
.label CIA2_TOD_SEC       = CIA2 + $09
.label CIA2_TOD_MIN       = CIA2 + $0A
.label CIA2_TOD_HOUR      = CIA2 + $0B
.label CIA2_IO_BUFFER     = CIA2 + $0C
.label CIA2_IRQ_CONTROL   = CIA2 + $0D
.label CIA2_CONTROL_A     = CIA2 + $0E
.label CIA2_CONTROL_B     = CIA2 + $0F

/*
 * Increases argument by one preserving its type (addressing mode). To be used in pseudocommands.
 *
 * Params:
 * arg: mnemonic argument
 */
.function incArgument(arg) {
  .return CmdArgument(arg.getType(), arg.getValue() + 1)
}

/*
 * Decrements 16 bit number located in memory address starting from "destination".
 *
 * MOD: -
 */
.macro dec16(destination) {
  dec16 destination
}

/*
 * Decrements 16 bit number located in memory address starting from "destination".
 *
 * MOD: -
 */
.pseudocommand dec16 destination {
  dec destination
  lda destination
  cmp #$ff
  bne !+
  dec incArgument(destination)
!:
}

.macro configureMemory(config) {
  lda MOS_6510_IO
  and #%11111000
  ora #[config & %00000111]
  sta MOS_6510_IO
}


.macro cmp16(value, low) {
  lda #<value
  cmp low
  bne end
  lda #>value
  cmp low + 1
end:
}

.macro disableCIAInterrupts() {
  lda #$7F                     
  sta CIA1_IRQ_CONTROL
  sta CIA2_IRQ_CONTROL
  lda CIA1_IRQ_CONTROL
  lda CIA2_IRQ_CONTROL
}

/*
 * Adds 16 bit number "value" to given memory cell specified by "low" address.
 *
 * MOD: A, C
 */
.macro add16(value, dest) {
  clc
  lda dest
  adc #<value
  sta dest
  lda dest + 1
  adc #>value
  sta dest + 1
}

// END: from c64lib library

.var splashBin = LoadBinary("graphics-linked.bin")

.macro load(block, bin, handler) {
    lda #block
    ldx #<bin.getSize()
    ldy #>bin.getSize()
    jsr handler
}

.segment CRT_FILE [outBin="demo.bin"]
    .segmentout [segments="BANK_LOADER"] // 8kb
    .segmentout [segments="BANK_SPLASH"] // 8kb
    .segmentout [segments="BANK_FILLER"]

.label crtUsageSize = (8 + 8)*1024
.label crtSize = 512*1024
.print "CRT size = " + crtSize
.print "CRT size = " + crtSize

.segmentdef BANK_LOADER     [min=$8000, max=$9fff, fill] // 0:1
.segmentdef BANK_SPLASH     [min=$8000, max=$9fff, fill] // 1:1

.segmentdef BANK_FILLER     [min=$8000, max=$8000 + crtSize - crtUsageSize - 1, fill]

.segmentdef LOADER [min=$0801]

.label INIT_LOADER = LOADER_START + $1d8
.label OVERWRITE_AREA = INIT_LOADER
.label SCREEN_ADDR = $400

.segment BANK_LOADER
* = $8000 "Loader"
bootstrapCodeBegin:
.byte <init, >init
.byte <initBasic, >initBasic
.byte $C3, $C2, $CD, $38, $30 // CBM80 signature

init:
    sei
    stx $d016
    jsr $fda3 // prepare irq
	jsr $fd50 // init memory
	jsr $fd15 // init i/o
	jsr $ff5b // init video
	cli
initBasic:

    .label sourceAdr = $8000 + bootstrapCodeEnd - bootstrapCodeBegin
    .label size = loaderCodeEnd - loaderCodeBegin

    lda #<sourceAdr
    sta SOURCE_PTR
    lda #>sourceAdr
    sta SOURCE_PTR + 1
    lda #$01
    sta DEST_PTR
    lda #$08
    sta DEST_PTR + 1
    lda #<size
    sta COUNTER
    lda #>size
    sta COUNTER + 1

    .print "source = " + sourceAdr
    .print "target = " + $0801
    .print "size = " + (loaderCodeEnd - loaderCodeBegin)

    copyNextPage:
        ldy #0
        copyNext:
            lda (SOURCE_PTR), y
            sta (DEST_PTR), y
            dec16(COUNTER)
            cmp16(0, COUNTER)
            beq end
            iny
            cpy #0
        bne copyNext
        inc SOURCE_PTR + 1
        inc DEST_PTR + 1
    jmp copyNextPage
    end:

    jmp $0801

bootstrapCodeEnd:
.segmentout[segments="LOADER"]

.segment LOADER
* = $0801 "Loader"
loaderCodeBegin:
    sei
    disableCIAInterrupts()
    configureMemory(RAM_IO_RAM)
    cli

    // load splash screen
    load(1, splashBin, loadPart)
    loop: jmp loop

loadPart: {
    jsr _setLoad
    ldx #<OVERWRITE_AREA
    lda #>OVERWRITE_AREA
    jsr _load
    jsr OVERWRITE_AREA
    rts
}

_setLoad: {
    sta _load.bank
    stx _load.sizeLo
    sty _load.sizeHi
    rts
}

_load: {
    jsr mdLoader.setTarget
    jsr configureForCart
    lda bank:#0
    ldx sizeLo:#0
    ldy sizeHi:#0
    jsr mdLoader.load
    jsr configureForGame
    rts
}

configureForCart: {
    sei
    configureMemory(BASIC_IO_KERNAL)
    cli
    rts
}

configureForGame: {
    sei
    configureMemory(RAM_IO_RAM)
    cli
    rts
}

mdLoader: createMagicDeskLoader()

loaderCodeEnd:

.segment BANK_SPLASH
* = $8000 "Splash screen"
.fill splashBin.getSize(), splashBin.get(i)
