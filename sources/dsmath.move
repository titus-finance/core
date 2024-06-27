// port of https://github.com/ribbon-finance/rvol/blob/master/contracts/libraries/DSMath.sol

module aptvol::dsmath {
    use std::vector;
    public fun add (x: u256, y:u256): u256 {
        return x + y
    }

    public fun sub (x: u256, y:u256): u256 {
        return x - y
    }

    public fun mul (x: u256, y: u256): u256 {
        return x * y
    }

    public fun min (x: u256, y: u256): u256 {
        if (x < y) x else y
    }

    public fun max (x: u256, y: u256): u256 {
        if (x > y) x else y
    }

    public fun sqrt (x: u256): u256 {
        if (x == 0) return x;
         // Set the initial guess to the closest power of two that is higher than x.
        let xAux: u256 = (x as u256);
        let result: u256 = 1;
         if (xAux >= 0x100000000000000000000000000000000) {
            xAux = xAux >> 128;
            result = result << 64;
        };
        if (xAux >= 0x10000000000000000) {
            xAux = xAux >> 64;
            result = result << 32;
        };
        if (xAux >= 0x100000000) {
            xAux = xAux >> 32;
            result = result << 16;
        };
        if (xAux >= 0x10000) {
            xAux = xAux >> 16;
            result = result << 8;
        };
        if (xAux >= 0x100) {
            xAux = xAux >> 8;
            result = result << 4;
        };
        if (xAux >= 0x10) {
            xAux = xAux >> 4;
            result = result << 2;
        };
        if (xAux >= 0x8) {
            result = result << 1;
        };
        // The operations can never overflow because the result is max 2^127 when it enters this block.
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1; // Seven iterations should be enough
        let roundedDownResult: u256 = x / result;
        if(result >= roundedDownResult) {
            return roundedDownResult;
        };
        result
    }
    // https://github.com/starcoinorg/starcoin-framework/blob/main/sources/Math.move#L56
    public fun pow(x: u64, y: u64): u128 {
        let result = 1u128;
        let z = y;
        let u = (x as u128);
        while (z > 0) {
            if (z % 2 == 1) {
                result = (u * result as u128);
            };
            u = (u * u as u128);
            z = z / 2;
        };
        result
    }

    public fun std_dev(input: vector<u256>): u256 {
        let sum: u256 = 0;
        let i = 0;
        let input_len = (vector::length(&input) as u256);
        while (i < input_len) {
            sum = sum + *vector::borrow(&input,(i as u64));
            i = i + 1;
        };
        let mean: u256 = sum/input_len;
        sum = 0;
        i = 0;
        while (i < input_len) {
            let mean_sub_from_input = ((*vector::borrow(&input, (i as u64)) - mean) as u256);
            sum = sum + (pow((mean_sub_from_input as u64),  2) as u256);
            i = i + 1;
        };

        let sd = sqrt(sum / (input_len - 1));
        sd
    }

    // https://github.com/ribbon-finance/rvol/blob/master/contracts/libraries/Math.sol#L40
     public fun sqrt2(x: u256): u256 {
        let z: u256 = (x + 1) / 2;
        let res = x;
        while (z < res) {
            res = z;
            z = (x / z + z) / 2;
        };
        res
    }

}