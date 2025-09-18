    .section .text
    .syntax unified
    .thumb

    .global main
    .global SysTick_Handler

// --- Definiciones de registros para STM32L476 ---
    .equ RCC_BASE,       0x40021000
    .equ RCC_AHB2ENR,    RCC_BASE + 0x4C
    .equ GPIOA_BASE,     0x48000000
    .equ GPIOA_MODER,    GPIOA_BASE + 0x00
    .equ GPIOA_ODR,      GPIOA_BASE + 0x14
    .equ GPIOC_BASE,     0x48000800
    .equ GPIOC_MODER,    GPIOC_BASE + 0x00
    .equ GPIOC_IDR,      GPIOC_BASE + 0x10
    .equ LED_PIN,        5
    .equ BUTTON_PIN,     13

// --- SysTick registros Cortex-M ---
    .equ SYST_CSR,   0xE000E010
    .equ SYST_RVR,   0xE000E014
    .equ SYST_CVR,   0xE000E018
    .equ HSI_FREQ,   4000000 
    .section .data
systick_done:
    .word 0           @ 0 = no expiró, 1 = expiró

    .section .text

main:
    // Habilitar clock para GPIOA y GPIOC
    movw    r0, #:lower16:RCC_AHB2ENR
    movt    r0, #:upper16:RCC_AHB2ENR
    ldr     r1, [r0]
    orr     r1, r1,  #(1<<0)|(1<<2)          // bit0=GPIOA, bit2=GPIOC
    str     r1, [r0]

    // PA5 como salida
    movw    r0, #:lower16:GPIOA_MODER
    movt    r0, #:upper16:GPIOA_MODER
    ldr     r1, [r0]
    bic     r1, r1, #(0x3 << (LED_PIN * 2))
    orr     r1, r1, #(0x1 << (LED_PIN * 2))
    str     r1, [r0]

    // PC13 como entrada
    movw    r0, #:lower16:GPIOC_MODER
    movt    r0, #:upper16:GPIOC_MODER
    ldr     r1, [r0]
    bic     r1, r1, #(0x3 << (BUTTON_PIN * 2))   // modo 00 (entrada)
    str     r1, [r0]

main_loop:
    // Leer botón
    movw    r0, #:lower16:GPIOC_IDR
    movt    r0, #:upper16:GPIOC_IDR
    ldr     r1, [r0]
    movw    r2, #(1 << BUTTON_PIN)
    tst     r1, r2
    bne     main_loop          // Si no presionado, seguir esperando

    // Encender LED
    movw    r0, #:lower16:GPIOA_ODR
    movt    r0, #:upper16:GPIOA_ODR
    ldr     r1, [r0]
    orr     r1, r1, #(1 << LED_PIN)
    str     r1, [r0]

    // --- Preparar SysTick: retardo de 3 s ---
    // RVR = 3_000_000 - 1 = 2_999_999
    movw    r0, #:lower16:SYST_RVR
    movt    r0, #:upper16:SYST_RVR
    movw    r1, #:lower16:HSI_FREQ*3
    movt    r1, #:upper16:HSI_FREQ*3
    subs    r1, r1, #1
    str     r1, [r0]

    // Resetear contador actual (CVR = 0)
    movw    r0, #:lower16:SYST_CVR
    movt    r0, #:upper16:SYST_CVR
    movs    r1, #0
    str     r1, [r0]

    // Asegurarse de limpiar la bandera software antes de arrancar
    movw    r0, #:lower16:systick_done
    movt    r0, #:upper16:systick_done
    movs    r1, #0
    str     r1, [r0]

    // Habilitar SysTick con interrupción (ENABLE=1, TICKINT=1, CLKSOURCE=1)
    movw    r0, #:lower16:SYST_CSR
    movt    r0, #:upper16:SYST_CSR
    movs    r1, #(1 << 0)|(1 << 1)|(1 << 2)  @ ENABLE=1, TICKINT=1, CLKSOURCE=1
    str     r1, [r0]

wait_systick_flag:
    // Esperar a que SysTick_Handler ponga systick_done = 1
    movw    r0, #:lower16:systick_done
    movt    r0, #:upper16:systick_done
    ldr     r1, [r0]
    cmp     r1, #1
    bne     wait_systick_flag

    // Limpiar bandera (para la próxima vez)
    movs    r1, #0
    str     r1, [r0]

    // Apagar LED
    movw    r0, #:lower16:GPIOA_ODR
    movt    r0, #:upper16:GPIOA_ODR
    ldr     r1, [r0]
    bic     r1, r1, #(1 << LED_PIN)
    str     r1, [r0]

    // --- Esperar a que suelte el botón ----
wait_release:
    movw    r0, #:lower16:GPIOC_IDR
    movt    r0, #:upper16:GPIOC_IDR
    ldr     r1, [r0]
    tst     r1, r2
    beq     wait_release

    // Volver al comienzo
    b main_loop

// ---------------- SysTick Handler ----------------
    .section .text
    .align  2
    .type   SysTick_Handler, %function
SysTick_Handler:
    // Deshabilitar SysTick (evita recurrencias)
    movw    r0, #:lower16:SYST_CSR
    movt    r0, #:upper16:SYST_CSR
    movs    r1, #0
    str     r1, [r0]

    // Poner la bandera systick_done = 1
    movw    r0, #:lower16:systick_done
    movt    r0, #:upper16:systick_done
    movs    r1, #1
    str     r1, [r0]

    bx      lr
