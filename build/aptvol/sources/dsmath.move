// port of https://github.com/ribbon-finance/rvol/blob/master/contracts/libraries/DSMath.sol

module aptvol::dsmath {
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
}