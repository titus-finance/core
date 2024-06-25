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
}