// https://github.com/ribbon-finance/rvol/blob/ee066ee4b612bb3c647b14cc48983045ec475f8c/contracts/libraries/Math.sol
module titusvol::math {
    use integer_mate::i256;

    const FIXED_1: u256 = 0x080000000000000000000000000000000;
    const FIXED_2: u256 = 0x100000000000000000000000000000000;
    const SQRT_1: u256 = 13043817825332782212;
    const LNX: u256 = 3988425491;
    const LOG_10_2: u256 = 3010299957;
    const LOG_E_2: u256 = 6931471806;
    const BASE: u256 = 10_000_000_000;

    public fun optimalExp(x: u256): u256 {
        let res: u256 = 0;
        let y: u256;
        let z: u256;

        y = x % 0x10000000000000000000000000000000; // get the input modulo 2^(-3)
        z = y;
        z = (z * y) / FIXED_1;
        res = res + z * 0x10e1b3be415a0000; // add y^02 * (20! / 02!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x05a0913f6b1e0000; // add y^03 * (20! / 03!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0168244fdac78000; // add y^04 * (20! / 04!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x004807432bc18000; // add y^05 * (20! / 05!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x000c0135dca04000; // add y^06 * (20! / 06!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0001b707b1cdc000; // add y^07 * (20! / 07!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x000036e0f639b800; // add y^08 * (20! / 08!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x00000618fee9f800; // add y^09 * (20! / 09!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0000009c197dcc00; // add y^10 * (20! / 10!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0000000e30dce400; // add y^11 * (20! / 11!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x000000012ebd1300; // add y^12 * (20! / 12!)
        z = (z * y) / FIXED_1;
        res = res +z * 0x0000000017499f00; // add y^13 * (20! / 13!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0000000001a9d480; // add y^14 * (20! / 14!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x00000000001c6380; // add y^15 * (20! / 15!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x000000000001c638; // add y^16 * (20! / 16!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0000000000001ab8; // add y^17 * (20! / 17!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x000000000000017c; // add y^18 * (20! / 18!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0000000000000014; // add y^19 * (20! / 19!)
        z = (z * y) / FIXED_1;
        res = res + z * 0x0000000000000001; // add y^20 * (20! / 20!)
        res = res / 0x21c3677c82b40000 + y + FIXED_1; // divide by 20! and then add y^1 / 1! + y^0 / 0!

        if ((x & 0x010000000000000000000000000000000) != 0)
            res =
                (res * 0x1c3d6a24ed82218787d624d3e5eba95f9) /
                0x18ebef9eac820ae8682b9793ac6d1e776; // multiply by e^2^(-3)
        if ((x & 0x020000000000000000000000000000000) != 0)
            res =
                (res * 0x18ebef9eac820ae8682b9793ac6d1e778) /
                0x1368b2fc6f9609fe7aceb46aa619baed4; // multiply by e^2^(-2)
        if ((x & 0x040000000000000000000000000000000) != 0)
            res =
                (res * 0x1368b2fc6f9609fe7aceb46aa619baed5) /
                0x0bc5ab1b16779be3575bd8f0520a9f21f; // multiply by e^2^(-1)
        if ((x & 0x080000000000000000000000000000000) != 0)
            res =
                (res * 0x0bc5ab1b16779be3575bd8f0520a9f21e) /
                0x0454aaa8efe072e7f6ddbab84b40a55c9; // multiply by e^2^(+0)
        if ((x & 0x100000000000000000000000000000000) != 0)
            res =
                (res * 0x0454aaa8efe072e7f6ddbab84b40a55c5) /
                0x00960aadc109e7a3bf4578099615711ea; // multiply by e^2^(+1)
        if ((x & 0x200000000000000000000000000000000) != 0)
            res =
                (res * 0x00960aadc109e7a3bf4578099615711d7) /
                0x0002bf84208204f5977f9a8cf01fdce3d; // multiply by e^2^(+2)
        if ((x & 0x400000000000000000000000000000000) != 0)
            res =
                (res * 0x0002bf84208204f5977f9a8cf01fdc307) /
                0x0000003c6ab775dd0b95b4cbee7e65d11; // multiply by e^2^(+3)

        res
    }

     public fun floorLog2(_n: u256): u8 {
        let res: u8 = 0;
        if (_n < 256) {
            // At most 8 iterations
            while (_n > 1) {
                _n =  _n >> 1;
                res = res + 1;
            };
        } else {
            // Exactly 8 iterations
            let s: u8 = 128;
            while (s > 0) {
                if (_n >= (1 as u256) << s) {
                    _n = _n >> s;
                    res = res | s;
                };
                s = s >> 1;
            };
        };
        res
    }

     public fun ln(x: u256): u256 {
        let res: u256 = 0;
        // If x >= 2, then we compute the integer part of log2(x), which is larger than 0.
        if (x >= FIXED_2) {
            let count: u8 = floorLog2(x / FIXED_1);
            x = x >> count; // now x < 2
            // note: we cast this to u256 bc unlike solidity, move needs us to have both operands the same type
            // see https://github.com/ribbon-finance/rvol/blob/master/contracts/libraries/Math.sol#L218 for original
            res = (count as u256) * FIXED_1;
        };
        // If x > 1, then we compute the fraction part of log2(x), which is larger than 0.
        if (x > FIXED_1) {
            let i: u8 = 127;
            while (i > 0) {
                x = (x * x) /  FIXED_1; // now 1 < x < 4
                if (x >= FIXED_2) {
                    x = x >> 1;
                    res = res + ((1 as u256) << (i-1))
                };
                i = i - 1;
            };
        };
        (res * LOG_E_2) / BASE
    }

    public fun abs(x: i256::I256): u256 {
        i256::abs_u256(x)
    }

    // normalized cdf
     public fun ncdf(x: u256): u256 {
        use integer_mate::i256;
        let t1: i256::I256 = i256::from(10_000_000+ ((2316419 * x) / FIXED_1));
        let exp: u256 = ((x / 2) * x) / FIXED_1;
        let numerator: i256::I256 = i256::from(3989423 * FIXED_1);
        let divisor: i256::I256 = i256::from(optimalExp(exp));
        let d: i256::I256 = i256::div(numerator, divisor);

        // we need to split this math:
        /*
        uint256 prob =
            uint256(
                (d *
                    (3193815 +
                        ((-3565638 +
                            ((17814780 +
                                ((-18212560 + (13302740 * 1e7) / t1) * 1e7) /
                                t1) * 1e7) /
                            t1) * 1e7) /
                        t1) *
                    1e7) / t1
            );*/
        // because we can't easily type cast between u256 and i256 like in soliditity
        let operand_1: i256::I256 = i256::from(13302740 * 10_000_000);
        let operand_2: i256::I256 = i256::neg_from(18212560);
        let operand_3: i256::I256 = i256::add(operand_1, operand_2);
        let operand_4: i256::I256 = i256::div(operand_3, t1);
        let operand_5: i256::I256 = i256::mul(operand_4, i256::from(10_000_000));
        let sum_one: i256::I256 = i256::add(operand_5, i256::from(17814780));
        let operand_6: i256::I256 = i256::div(sum_one, t1);
        let operand_7: i256::I256 = i256::mul(operand_6, i256::from(10_000_000));
        let sum_two: i256::I256 = i256::add(i256::neg_from(3565638), operand_7);
        let operand_8: i256::I256 = i256::div(sum_two, t1);
        let operand_9: i256::I256 = i256::mul(operand_8, i256::from(10_000_000));
        let sum_three: i256::I256 = i256::add(i256::from(3193815), operand_9);
        let operand_10: i256::I256 = i256::div(sum_three, t1);
        let operand_11: i256::I256 = i256::mul(operand_10, i256::from(10_000_000));
        let operand_12: i256::I256 = i256::mul(operand_11, d);
        let prob: i256::I256 = i256::div(operand_12, t1);
        

        if (x > 0) {prob = i256::sub(i256::from(100_000_000_000_000), prob)};
        i256::as_u256(prob)
    }

     #[test]
     fun test_abs() {
        use integer_mate::i256;
        let x: i256::I256 = i256::neg_from(82);
        let abs_x = abs(x);
        assert!(abs_x == 82, 0)
     }

    #[test]
    public fun test_ncdf() {
        use integer_mate::i256;

        let x1: u256 = 0;
        let x2: u256 = 1_000_000;
        let x3: u256 = i256::as_u256(i256::neg_from(1_000_000));

        let result1: u256 = ncdf(x1);
        let result2: u256 = ncdf(x2);
        let result3: u256 = ncdf(x3);

        // Expected values for the CDF of the standard normal distribution
        let expected1: u256 = 50000000000000;
        let expected2: u256 = 84134474600000;
        let expected3: u256 = 15865525400000;

        assert!(result1 == expected1, 101);
        assert!(result2 == expected2, 102);
        assert!(result3 == expected3, 103);
    }


}