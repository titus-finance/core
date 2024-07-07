module integer_mate::i256 {
    use std::error;
    use integer_mate::i64;
    use integer_mate::i32;

    const OVERFLOW: u64 = 0;

    const MIN_AS_U256: u256 = 1 << 255;
    const MAX_AS_U256: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    const LT: u8 = 0;
    const EQ: u8 = 1;
    const GT: u8 = 2;

    struct I256 has copy, drop, store {
        bits: u256
    }

    public fun zero(): I256 {
        I256 {
            bits: 0
        }
    }

    public fun from(v: u256): I256 {
        assert!(v <= MAX_AS_U256, error::invalid_argument(OVERFLOW));
        I256 {
            bits: v
        }
    }

    public fun neg_from(v: u256): I256 {
        assert!(v <= MIN_AS_U256, error::invalid_argument(OVERFLOW));
        if (v == 0) {
            I256 {
                bits: v
            }
        } else {
            I256 {
                bits: (u256_neg(v)  + 1) | (1 << 255)
            }
        }

    }

    public fun neg(v: I256): I256 {
        if (is_neg(v)) {
            abs(v)
        } else {
            neg_from(v.bits)
        }
    }

    public fun wrapping_add(num1: I256, num2:I256): I256 {
        let sum = num1.bits ^ num2.bits;
        let carry = (num1.bits & num2.bits) << 1;
        while (carry != 0) {
            let a = sum;
            let b = carry;
            sum = a ^ b;
            carry = (a & b) << 1;
        };
        I256 {
            bits: sum
        }
    }

    public fun add(num1: I256, num2: I256): I256 {
        let sum = wrapping_add(num1, num2);
        let overflow = (sign(num1) & sign(num2) & u8_neg(sign(sum))) + (u8_neg(sign(num1)) & u8_neg(sign(num2)) & sign(sum));
        assert!(overflow == 0, error::invalid_argument(OVERFLOW));
        sum
    }

    public fun overflowing_add(num1: I256, num2: I256): (I256, bool) {
        let sum = wrapping_add(num1, num2);
        let overflow = (sign(num1) & sign(num2) & u8_neg(sign(sum))) + (u8_neg(sign(num1)) & u8_neg(sign(num2)) & sign(sum));
        (sum, overflow != 0)
    }

    public fun wrapping_sub(num1: I256, num2: I256): I256 {
        let sub_num = wrapping_add(I256 {
            bits: u256_neg(num2.bits)
        }, from(1));
        wrapping_add(num1, sub_num)
    }
    
    public fun sub(num1: I256, num2: I256): I256 {
        let sub_num = wrapping_add(I256 {
            bits: u256_neg(num2.bits)
        }, from(1));
        add(num1, sub_num)
    }

    public fun overflowing_sub(num1: I256, num2: I256): (I256, bool) {
        let sub_num = wrapping_add(I256 {
            bits: u256_neg(num2.bits)
        }, from(1));
        let sum = wrapping_add(num1, sub_num);
        let overflow = (sign(num1) & sign(sub_num) & u8_neg(sign(sum))) + (u8_neg(sign(num1)) & u8_neg(sign(sub_num)) & sign(sum));
        (sum, overflow != 0)
    }

    public fun mul(num1: I256, num2: I256): I256 {
        let product = abs_u256(num1) * abs_u256(num2);
        if (sign(num1) != sign(num2)) {
           return neg_from(product)
        };
        return from(product)
    }

    public fun div(num1: I256, num2: I256): I256 {
        let result = abs_u256(num1) / abs_u256(num2);
        if (sign(num1) != sign(num2)) {
           return neg_from(result)
        };
        return from(result)
    }

    public fun abs(v: I256): I256 {
        if (sign(v) == 0) {
            v
        } else {
            assert!(v.bits > MIN_AS_U256, error::invalid_argument(OVERFLOW));
            return I256 {
                bits: u256_neg(v.bits - 1)
            }
        }
    }

    public fun abs_u256(v: I256): u256 {
        if (sign(v) == 0) {
            v.bits
        } else {
            u256_neg(v.bits - 1)
        }
    }

    public fun shl(v: I256, shift: u8): I256 {
        I256 {
            bits: v.bits << shift
        }
    }

    public fun shr(v: I256, shift: u8): I256 {
        if (shift == 0) {
            return v
        };
        let mask = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF << ((256u16 - (shift as u16)) as u8);
        if (sign(v) == 1) {
            return I256 {
                bits: (v.bits >> shift) | mask
            }
        };
        I256 {
            bits: v.bits >> shift
        }
    }

    public fun as_u256(v: I256): u256 {
        v.bits
    }

    public fun as_i64(v: I256): i64::I64 {
        if (is_neg(v)) {
           return i64::neg_from((abs_u256(v) as u64))
        } else {
            return i64::from((abs_u256(v) as u64))
        }
    }

    public fun as_i32(v: I256): i32::I32 {
        if (is_neg(v)) {
            return i32::neg_from((abs_u256(v) as u32))
        } else {
            return i32::from((abs_u256(v) as u32))
        }
    }

    public fun sign(v: I256): u8 {
        ((v.bits >> 255) as u8)
    }

    public fun is_neg(v: I256): bool {
        sign(v) == 1
    }

    public fun cmp(num1: I256, num2: I256): u8 {
        if (num1.bits == num2.bits) return EQ;
        if (sign(num1) > sign(num2)) return LT;
        if (sign(num1) < sign(num2)) return GT;
        if (num1.bits > num2.bits) {
            return GT
        } else {
            return LT
        }
    }

    public fun eq(num1: I256, num2: I256): bool {
        num1.bits == num2.bits
    }

    public fun gt(num1: I256, num2: I256): bool {
        cmp(num1, num2) == GT
    }
    
    public fun gte(num1: I256, num2: I256): bool {
        cmp(num1, num2) >= EQ
    }
    
    public fun lt(num1: I256, num2: I256): bool {
        cmp(num1, num2) == LT
    }
    
    public fun lte(num1: I256, num2: I256): bool {
        cmp(num1, num2) <= EQ
    }

    public fun or(num1: I256, num2: I256): I256 {
        I256 {
            bits: (num1.bits | num2.bits)
        }
    }

    public fun and(num1: I256, num2: I256): I256 {
        I256 {
            bits: (num1.bits & num2.bits)
        }
    }

    fun u256_neg(v :u256) : u256 {
        v ^ 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    }

    fun u8_neg(v: u8): u8 {
        v ^ 0xff
    }

    #[test]
    fun test_from_ok() {
        assert!(as_u256(from(0)) == 0, 0);
        assert!(as_u256(from(10)) == 10, 1);
    }

    #[test]
    #[expected_failure]
    fun test_from_overflow() {
        as_u256(from(MIN_AS_U256));
        as_u256(from(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    }

    #[test]
    fun test_neg_from() {
        assert!(as_u256(neg_from(0)) == 0, 0);
        assert!(as_u256(neg_from(1)) == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 1);
        assert!(as_u256(neg_from(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) == 0x8000000000000000000000000000000000000000000000000000000000000001, 2);
        assert!(as_u256(neg_from(MIN_AS_U256)) == MIN_AS_U256, 2);
    }

    #[test]
    #[expected_failure]
    fun test_neg_from_overflow() {
        neg_from(0x8000000000000000000000000000000000000000000000000000000000000001);
    }

    #[test]
    fun test_abs() {
        assert!(as_u256(from(10)) == 10u256, 0); 
        assert!(as_u256(abs(neg_from(10))) == 10u256, 1); 
        assert!(as_u256(abs(neg_from(0))) == 0u256, 2); 
        assert!(as_u256(abs(neg_from(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))) == 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 3); 
        assert!(as_u256(neg_from(MIN_AS_U256)) == MIN_AS_U256, 4);
    }

    #[test]
    #[expected_failure]
    fun test_abs_overflow() {
        abs(neg_from(1<<255));
    }

    #[test]
    fun test_wrapping_add() {
        assert!(as_u256(wrapping_add(from(0), from(1))) == 1, 0);
        assert!(as_u256(wrapping_add(from(1), from(0))) == 1, 0);
        assert!(as_u256(wrapping_add(from(10000), from(99999))) == 109999, 0);
        assert!(as_u256(wrapping_add(from(99999), from(10000))) == 109999, 0);
        assert!(as_u256(wrapping_add(from(MAX_AS_U256-1), from(1))) == MAX_AS_U256, 0);

        assert!(as_u256(wrapping_add(neg_from(0), neg_from(0))) == 0, 1);
        assert!(as_u256(wrapping_add(neg_from(1), neg_from(0))) == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 1);
        assert!(as_u256(wrapping_add(neg_from(0), neg_from(1))) == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 1);
        assert!(as_u256(wrapping_add(neg_from(10000), neg_from(99999))) == 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe5251, 1);
        assert!(as_u256(wrapping_add(neg_from(99999), neg_from(10000))) == 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe5251, 1);
        assert!(as_u256(wrapping_add(neg_from(MIN_AS_U256-1), neg_from(1))) == MIN_AS_U256, 1);

        assert!(as_u256(wrapping_add(from(0), neg_from(0))) == 0, 2);
        assert!(as_u256(wrapping_add(neg_from(0), from(0))) == 0, 2);
        assert!(as_u256(wrapping_add(neg_from(1), from(1))) == 0, 2);
        assert!(as_u256(wrapping_add(from(1), neg_from(1))) == 0, 2);
        assert!(as_u256(wrapping_add(from(10000), neg_from(99999))) == 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffea071, 2);
        assert!(as_u256(wrapping_add(from(99999), neg_from(10000))) == 89999, 2);
        assert!(as_u256(wrapping_add(neg_from(MIN_AS_U256), from(1))) == 0x8000000000000000000000000000000000000000000000000000000000000001, 2);

        assert!(as_u256(wrapping_add(from(MAX_AS_U256), from(1))) == MIN_AS_U256, 2);
    }

    #[test]
    fun test_add() {
        assert!(as_u256(add(from(0), from(0))) == 0, 0);
        assert!(as_u256(add(from(0), from(1))) == 1, 0);
        assert!(as_u256(add(from(1), from(0))) == 1, 0);
        assert!(as_u256(add(from(10000), from(99999))) == 109999, 0);
        assert!(as_u256(add(from(99999), from(10000))) == 109999, 0);
        assert!(as_u256(add(from(MAX_AS_U256-1), from(1))) == MAX_AS_U256, 0);

        assert!(as_u256(add(neg_from(0), neg_from(0))) == 0, 1);
        assert!(as_u256(add(neg_from(1), neg_from(0))) == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 1);
        assert!(as_u256(add(neg_from(0), neg_from(1))) == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 1);
        assert!(as_u256(add(neg_from(10000), neg_from(99999))) == 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe5251, 1);
        assert!(as_u256(add(neg_from(99999), neg_from(10000))) == 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe5251, 1);
        assert!(as_u256(add(neg_from(MIN_AS_U256-1), neg_from(1))) == MIN_AS_U256, 1);

        assert!(as_u256(add(from(0), neg_from(0))) == 0, 2);
        assert!(as_u256(add(neg_from(0), from(0))) == 0, 2);
        assert!(as_u256(add(neg_from(1), from(1))) == 0, 2);
        assert!(as_u256(add(from(1), neg_from(1))) == 0, 2);
        assert!(as_u256(add(from(10000), neg_from(99999))) == 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffea071, 2);
        assert!(as_u256(add(from(99999), neg_from(10000))) == 89999, 2);
        assert!(as_u256(add(neg_from(MIN_AS_U256), from(1))) == 0x8000000000000000000000000000000000000000000000000000000000000001, 2);
        assert!(as_u256(add(from(MAX_AS_U256), neg_from(1))) == MAX_AS_U256 - 1, 2);
    }

    #[test]
    fun test_overflowing_add() {
        let (result, overflow) = overflowing_add(from(MAX_AS_U256), neg_from(1));
        assert!(overflow == false && as_u256(result) == MAX_AS_U256 - 1, 1);
        let (_, overflow) = overflowing_add(from(MAX_AS_U256), from(1));
        assert!(overflow == true, 1);
        let (_, overflow) = overflowing_add(neg_from(MIN_AS_U256), neg_from(1));
        assert!(overflow == true, 1);
    }

    #[test]
    #[expected_failure]
    fun test_add_overflow() {
        add(from(MAX_AS_U256), from(1));
    }

    #[test]
    #[expected_failure]
    fun test_add_underflow() {
        add(neg_from(MIN_AS_U256), neg_from(1));
    }

    #[test]
    fun test_wrapping_sub() {
        assert!(as_u256(wrapping_sub(from(0), from(0))) == 0, 0);
        assert!(as_u256(wrapping_sub(from(1), from(0))) == 1, 0);
        assert!(as_u256(wrapping_sub(from(0), from(1))) == as_u256(neg_from(1)), 0);
        assert!(as_u256(wrapping_sub(from(1), from(1))) == as_u256(neg_from(0)), 0);
        assert!(as_u256(wrapping_sub(from(1), neg_from(1))) == as_u256(from(2)), 0);
        assert!(as_u256(wrapping_sub(neg_from(1), from(1))) == as_u256(neg_from(2)), 0);
        assert!(as_u256(wrapping_sub(from(1000000), from(1))) == 999999, 0);
        assert!(as_u256(wrapping_sub(neg_from(1000000), neg_from(1))) == as_u256(neg_from(999999)), 0);
        assert!(as_u256(wrapping_sub(from(1), from(1000000))) == as_u256(neg_from(999999)), 0);
        assert!(as_u256(wrapping_sub(from(MAX_AS_U256), from(MAX_AS_U256))) == as_u256(from(0)), 0);
        assert!(as_u256(wrapping_sub(from(MAX_AS_U256), from(1))) == as_u256(from(MAX_AS_U256 - 1)), 0);
        assert!(as_u256(wrapping_sub(from(MAX_AS_U256), neg_from(1))) == as_u256(neg_from(MIN_AS_U256)), 0);
        assert!(as_u256(wrapping_sub(neg_from(MIN_AS_U256), neg_from(1))) == as_u256(neg_from(MIN_AS_U256 - 1)), 0);
        assert!(as_u256(wrapping_sub(neg_from(MIN_AS_U256), from(1))) == as_u256(from(MAX_AS_U256)), 0);
    }

    #[test]
    fun test_sub() {
        assert!(as_u256(sub(from(0), from(0))) == 0, 0);
        assert!(as_u256(sub(from(1), from(0))) == 1, 0);
        assert!(as_u256(sub(from(0), from(1))) == as_u256(neg_from(1)), 0);
        assert!(as_u256(sub(from(1), from(1))) == as_u256(neg_from(0)), 0);
        assert!(as_u256(sub(from(1), neg_from(1))) == as_u256(from(2)), 0);
        assert!(as_u256(sub(neg_from(1), from(1))) == as_u256(neg_from(2)), 0);
        assert!(as_u256(sub(from(1000000), from(1))) == 999999, 0);
        assert!(as_u256(sub(neg_from(1000000), neg_from(1))) == as_u256(neg_from(999999)), 0);
        assert!(as_u256(sub(from(1), from(1000000))) == as_u256(neg_from(999999)), 0);
        assert!(as_u256(sub(from(MAX_AS_U256), from(MAX_AS_U256))) == as_u256(from(0)), 0);
        assert!(as_u256(sub(from(MAX_AS_U256), from(1))) == as_u256(from(MAX_AS_U256 - 1)), 0);
        assert!(as_u256(sub(neg_from(MIN_AS_U256), neg_from(1))) == as_u256(neg_from(MIN_AS_U256 - 1)), 0);
    }

    #[test]
    fun test_checked_sub() {
        let (result, overflowing) = overflowing_sub(from(MAX_AS_U256), from(1));
        assert!(overflowing == false && as_u256(result) == MAX_AS_U256 - 1, 1);

        let (_, overflowing) = overflowing_sub(neg_from(MIN_AS_U256), from(1));
        assert!(overflowing == true, 1);

        let (_, overflowing) = overflowing_sub(from(MAX_AS_U256), neg_from(1));
        assert!(overflowing == true, 1);
    }

    #[test]
    #[expected_failure]
    fun test_sub_overflow() {
        sub(from(MAX_AS_U256), neg_from(1));
    }

    #[test]
    #[expected_failure]
    fun test_sub_underflow() {
        sub(neg_from(MIN_AS_U256), from(1));
    }

    #[test]
    fun test_mul() {
        assert!(as_u256(mul(from(1), from(1))) == 1, 0);
        assert!(as_u256(mul(from(10), from(10))) == 100, 0);
        assert!(as_u256(mul(from(100), from(100))) == 10000, 0);
        assert!(as_u256(mul(from(10000), from(10000))) == 100000000, 0);

        assert!(as_u256(mul(neg_from(1), from(1))) == as_u256(neg_from(1)), 0);
        assert!(as_u256(mul(neg_from(10), from(10))) == as_u256(neg_from(100)), 0);
        assert!(as_u256(mul(neg_from(100), from(100))) == as_u256(neg_from(10000)), 0);
        assert!(as_u256(mul(neg_from(10000), from(10000))) == as_u256(neg_from(100000000)), 0);

        assert!(as_u256(mul(from(1), neg_from(1))) == as_u256(neg_from(1)), 0);
        assert!(as_u256(mul(from(10), neg_from(10))) == as_u256(neg_from(100)), 0);
        assert!(as_u256(mul(from(100), neg_from(100))) == as_u256(neg_from(10000)), 0);
        assert!(as_u256(mul(from(10000), neg_from(10000))) == as_u256(neg_from(100000000)), 0);
        assert!(as_u256(mul(from(MIN_AS_U256/2), neg_from(2))) == as_u256(neg_from(MIN_AS_U256)), 0);
    }

    #[test]
    #[expected_failure]
    fun test_mul_overflow() {
        mul(from(MIN_AS_U256/2), from(1));
        mul(neg_from(MIN_AS_U256/2), neg_from(2));
    }
    
    #[test]
    fun test_div() {
        assert!(as_u256(div(from(0), from(1))) == 0, 0);
        assert!(as_u256(div(from(10), from(1))) == 10, 0);
        assert!(as_u256(div(from(10), neg_from(1))) == as_u256(neg_from(10)), 0);
        assert!(as_u256(div(neg_from(10), neg_from(1))) == as_u256(from(10)), 0);

        assert!(abs_u256(neg_from(MIN_AS_U256)) == MIN_AS_U256, 0);
        assert!(as_u256(div(neg_from(MIN_AS_U256), from(1))) == MIN_AS_U256, 0);
    }

    #[test]
    #[expected_failure]
    fun test_div_overflow() {
        div(neg_from(MIN_AS_U256), neg_from(1));
    }

    #[test]
    fun test_shl() {
        assert!(as_u256(shl(from(10), 0)) == 10, 0);
        assert!(as_u256(shl(neg_from(10), 0)) == as_u256(neg_from(10)), 0);

        assert!(as_u256(shl(from(10), 1)) == 20, 0);
        assert!(as_u256(shl(neg_from(10), 1)) == as_u256(neg_from(20)), 0);

        assert!(as_u256(shl(from(10), 8)) == 2560, 0);
        assert!(as_u256(shl(neg_from(10), 8)) == as_u256(neg_from(2560)), 0);

        assert!(as_u256(shl(from(10), 32)) == 42949672960, 0);
        assert!(as_u256(shl(neg_from(10), 32)) == as_u256(neg_from(42949672960)), 0);

        assert!(as_u256(shl(from(10), 64)) == 184467440737095516160, 0);
        assert!(as_u256(shl(neg_from(10), 64)) == as_u256(neg_from(184467440737095516160)), 0);

        assert!(as_u256(shl(from(10), 255)) == 0, 0);
        assert!(as_u256(shl(neg_from(10), 255)) == 0, 0);
    }

    #[test]
    fun test_shr() {
        assert!(as_u256(shr(from(10), 0)) == 10, 0);
        assert!(as_u256(shr(neg_from(10), 0)) == as_u256(neg_from(10)), 0);

        assert!(as_u256(shr(from(10), 1)) == 5, 0);
        assert!(as_u256(shr(neg_from(10), 1)) == as_u256(neg_from(5)), 0);
        
        assert!(as_u256(shr(from(MAX_AS_U256), 8)) == 0x007FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);
        assert!(as_u256(shr(neg_from(MIN_AS_U256), 8)) == 0xFF80000000000000000000000000000000000000000000000000000000000000, 0);

        assert!(as_u256(shr(from(MAX_AS_U256), 96)) == 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);
        assert!(as_u256(shr(neg_from(MIN_AS_U256), 96)) == 0xffffffffffffffffffffffff8000000000000000000000000000000000000000, 0);

        assert!(as_u256(shr(from(MAX_AS_U256), 255)) == 0, 0);
        assert!(as_u256(shr(neg_from(MIN_AS_U256), 255)) == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);
    }

    #[test]
    fun test_sign() {
        assert!(sign(neg_from(10)) == 1u8, 0);
        assert!(sign(from(10)) == 0u8, 0);
    }

    #[test]
    fun test_cmp() {
        assert!(cmp(from(1), from(0)) == GT, 0);
        assert!(cmp(from(0), from(1)) == LT, 0);

        assert!(cmp(from(0), neg_from(1)) == GT, 0);
        assert!(cmp(neg_from(0), neg_from(1)) == GT, 0);
        assert!(cmp(neg_from(1), neg_from(0)) == LT, 0);

        assert!(cmp(neg_from(MIN_AS_U256), from(MAX_AS_U256)) == LT, 0);
        assert!(cmp(from(MAX_AS_U256), neg_from(MIN_AS_U256)) == GT, 0);

        assert!(cmp(from(MAX_AS_U256), from(MAX_AS_U256-1)) == GT, 0);
        assert!(cmp(from(MAX_AS_U256-1), from(MAX_AS_U256)) == LT, 0);

        assert!(cmp(neg_from(MIN_AS_U256), neg_from(MIN_AS_U256-1)) == LT, 0);
        assert!(cmp(neg_from(MIN_AS_U256-1), neg_from(MIN_AS_U256)) == GT, 0);
    }

    #[test]
    fun test_castdown() {
        assert!((1u128 as u8) == 1u8, 0);
    }
}

