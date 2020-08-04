/*
    Copyright 2018 0KIMS association.

    This file is part of circom (Zero Knowledge Circuit Compiler).

    circom is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    circom is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with circom. If not, see <https://www.gnu.org/licenses/>.
*/

include "../../../basics/comparators/comp_constant/comp_constant.circom";
include "../../../basics/comparators/is_zero/is_zero.circom";
include "../../../basics/comparators/force_equal_if_enabled/force_equal_if_enabled.circom";
include "../../../basics/bitify/num2bits/num2bits.circom";
include "../../../basics/bitify/num2bits_strict/num2bits_strict.circom";
include "../../baby_jubjub/baby_edwards_add/baby_edwards_add.circom";
include "../../baby_jubjub/baby_edwards_dbl/baby_edwards_dbl.circom";
include "../../baby_jubjub/baby_edwards_scalar_mul_any/baby_edwards_scalar_mul_any.circom";
include "../../baby_jubjub/baby_edwards_scalar_mul_fix/baby_edwards_scalar_mul_fix.circom";
include "../../hash_functions/mimc_sponge/mimc_sponge.circom";

template EdDSAMiMCSpongeVerifier() {
    signal input enabled;
    signal input Ax;
    signal input Ay;

    signal input S;
    signal input R8x;
    signal input R8y;

    signal input M;

    var i;

// Ensure S < subgroup order

    component snum2bits = Num2Bits(253);
    snum2bits.in <== S;

    component  compConstant = CompConstant(2736030358979909402780800718157159386076813972158567259200215660948447373040);

    for (i=0; i<253; i++) {
        snum2bits.out[i] ==> compConstant.in[i];
    }
    compConstant.in[253] <== 0;
    compConstant.out === 0;

// Calculate the h = H(R, A, msg)

    component hash = MiMCSponge(5, 220, 1);
    hash.ins[0] <== R8x;
    hash.ins[1] <== R8y;
    hash.ins[2] <== Ax;
    hash.ins[3] <== Ay;
    hash.ins[4] <== M;
    hash.k <== 0;

    component h2bits = Num2Bits_strict();
    h2bits.in <== hash.outs[0];

// Calculate second part of the right side:  right2 = h*8*A

    // Multiply by 8 by adding it 3 times and check != O. 
    // This also ensures that the result is in the subgroup.
    component dbl1 = BabyEdwardsDbl();
    dbl1.x <== Ax;
    dbl1.y <== Ay;
    component dbl2 = BabyEdwardsDbl();
    dbl2.x <== dbl1.xout;
    dbl2.y <== dbl1.yout;
    component dbl3 = BabyEdwardsDbl();
    dbl3.x <== dbl2.xout;
    dbl3.y <== dbl2.yout;

    // We check that A is not zero.
    component isZero = IsZero();
    isZero.in <== dbl3.x;
    isZero.out === 0;

    component mulAny = BabyEdwardsScalarMulAny(254);
    for (i=0; i<254; i++) {
        mulAny.e[i] <== h2bits.out[i];
    }
    mulAny.p[0] <== dbl3.xout;
    mulAny.p[1] <== dbl3.yout;


// Compute the right side: right =  R8 + right2

    component addRight = BabyEdwardsAdd();
    addRight.x1 <== R8x;
    addRight.y1 <== R8y;
    addRight.x2 <== mulAny.out[0];
    addRight.y2 <== mulAny.out[1];

// Calculate left side of equation left = S*B8

    var BASE8[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];
    component mulFix = BabyEdwardsScalarMulFix(253, BASE8);
    for (i=0; i<253; i++) {
        mulFix.e[i] <== snum2bits.out[i];
    }

// Do the comparation left == right if enabled;

    component eqCheckX = ForceEqualIfEnabled();
    eqCheckX.enabled <== enabled;
    eqCheckX.in[0] <== mulFix.out[0];
    eqCheckX.in[1] <== addRight.xout;

    component eqCheckY = ForceEqualIfEnabled();
    eqCheckY.enabled <== enabled;
    eqCheckY.in[0] <== mulFix.out[1];
    eqCheckY.in[1] <== addRight.yout;
}