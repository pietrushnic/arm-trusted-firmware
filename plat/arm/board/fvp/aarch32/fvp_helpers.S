/*
 * Copyright (c) 2016, ARM Limited and Contributors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Neither the name of ARM nor the names of its contributors may be used
 * to endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <arch.h>
#include <asm_macros.S>
#include <platform_def.h>
#include "../drivers/pwrc/fvp_pwrc.h"
#include "../fvp_def.h"

	.globl	plat_get_my_entrypoint
	.globl	plat_is_my_cpu_primary

	/* ---------------------------------------------------------------------
	 * unsigned long plat_get_my_entrypoint (void);
	 *
	 * Main job of this routine is to distinguish between a cold and warm
	 * boot. On FVP, this information can be queried from the power
	 * controller. The Power Control SYS Status Register (PSYSR) indicates
	 * the wake-up reason for the CPU.
	 *
	 * For a cold boot, return 0.
	 * For a warm boot, read the mailbox and return the address it contains.
	 *
	 * TODO: PSYSR is a common register and should be
	 * 	accessed using locks. Since it is not possible
	 * 	to use locks immediately after a cold reset
	 * 	we are relying on the fact that after a cold
	 * 	reset all cpus will read the same WK field
	 * ---------------------------------------------------------------------
	 */
func plat_get_my_entrypoint
	/* ---------------------------------------------------------------------
	 * When bit PSYSR.WK indicates either "Wake by PPONR" or "Wake by GIC
	 * WakeRequest signal" then it is a warm boot.
	 * ---------------------------------------------------------------------
	 */
	ldcopr	r2, MPIDR
	ldr	r1, =PWRC_BASE
	str	r2, [r1, #PSYSR_OFF]
	ldr	r2, [r1, #PSYSR_OFF]
	ubfx	r2, r2, #PSYSR_WK_SHIFT, #PSYSR_WK_WIDTH
	cmp	r2, #WKUP_PPONR
	beq	warm_reset
	cmp	r2, #WKUP_GICREQ
	beq	warm_reset

	/* Cold reset */
	mov	r0, #0
	bx	lr

warm_reset:
	/* ---------------------------------------------------------------------
	 * A mailbox is maintained in the trusted SRAM. It is flushed out of the
	 * caches after every update using normal memory so it is safe to read
	 * it here with SO attributes.
	 * ---------------------------------------------------------------------
	 */
	ldr	r0, =PLAT_ARM_TRUSTED_MAILBOX_BASE
	ldr	r0, [r0]
	cmp	r0, #0
	beq	_panic
	bx	lr

	/* ---------------------------------------------------------------------
	 * The power controller indicates this is a warm reset but the mailbox
	 * is empty. This should never happen!
	 * ---------------------------------------------------------------------
	 */
_panic:
	b	_panic
endfunc plat_get_my_entrypoint

	/* -----------------------------------------------------
	 * unsigned int plat_is_my_cpu_primary (void);
	 *
	 * Find out whether the current cpu is the primary
	 * cpu.
	 * -----------------------------------------------------
	 */
func plat_is_my_cpu_primary
	ldcopr	r0, MPIDR
	ldr	r1, =(MPIDR_CLUSTER_MASK | MPIDR_CPU_MASK)
	and	r0, r1
	cmp	r0, #FVP_PRIMARY_CPU
	moveq	r0, #1
	movne	r0, #0
	bx	lr
endfunc plat_is_my_cpu_primary
