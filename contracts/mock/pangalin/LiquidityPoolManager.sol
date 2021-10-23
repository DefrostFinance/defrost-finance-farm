// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../openzeppelin/contracts/ownership/Ownable.sol";
import "../openzeppelin/contracts/math/SafeMath.sol";
import "../openzeppelin/contracts/utils/EnumerableSet.sol";
import "../openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./StakingRewards.sol";

/**
 * Contract to distribute PNG tokens to whitelisted trading pairs. After deploying,
 * whitelist the desired pairs and set the avaxPngPair. When initial administration
 * is complete. Ownership should be transferred to the Timelock governance contract.
 */
contract LiquidityPoolManager is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint;

    // Whitelisted pairs that offer PNG rewards
    // Note: AVAX/PNG is an AVAX pair
    EnumerableSet.AddressSet private avaxPairs;
    EnumerableSet.AddressSet private pngPairs;

    // Maps pairs to their associated StakingRewards contract
    mapping(address => address) public stakes;

    // Known contract addresses for WAVAX and PNG
    address public wavax;
    address public png;

    // AVAX/PNG pair used to determine PNG liquidity
    address public avaxPngPair;

    uint public numPools = 0;

    bool private readyToDistribute = false;

    // Tokens to distribute to each pool. Indexed by avaxPairs then pngPairs.
    uint[] public distribution;

    uint public unallocatedPng = 0;

    constructor(address wavax_,
                address png_) public {
        require(wavax_ != address(0) && png_ != address(0),
                "LiquidityPoolManager::constructor: Arguments can't be the zero address");
        wavax = wavax_;
        png = png_;
    }

    /**
     * Check if the given pair is a whitelisted pair
     *
     * Args:
     *   pair: pair to check if whitelisted
     *
     * Return: True if whitelisted
     */
    function isWhitelisted(address pair) public view returns (bool) {
        return avaxPairs.contains(pair) || pngPairs.contains(pair);
    }

    /**
     * Check if the given pair is a whitelisted AVAX pair. The AVAX/PNG pair is
     * considered an AVAX pair.
     *
     * Args:
     *   pair: pair to check
     *
     * Return: True if whitelisted and pair contains AVAX
     */
    function isAvaxPair(address pair) external view returns (bool) {
        return avaxPairs.contains(pair);
    }

    /**
     * Check if the given pair is a whitelisted PNG pair. The AVAX/PNG pair is
     * not considered a PNG pair.
     *
     * Args:
     *   pair: pair to check
     *
     * Return: True if whitelisted and pair contains PNG but is not AVAX/PNG pair
     */
    function isPngPair(address pair) external view returns (bool) {
        return pngPairs.contains(pair);
    }

    /**
     * Sets the AVAX/PNG pair. Pair's tokens must be AVAX and PNG.
     *
     * Args:
     *   pair: AVAX/PNG pair
     */
    function setAvaxPngPair(address avaxPngPair_) external onlyOwner {
        require(avaxPngPair_ != address(0), 'LiquidityPoolManager::setAvaxPngPair: Pool cannot be the zero address');
        avaxPngPair = avaxPngPair_;
    }

    /**
     * Adds a new whitelisted liquidity pool pair. Generates a staking contract.
     * Liquidity providers may stake this liquidity provider reward token and
     * claim PNG rewards proportional to their stake. Pair must contain either
     * AVAX or PNG.
     *
     * Args:
     *   pair: pair to whitelist
     */
    function addWhitelistedPool(address pair) external  {
        require(!readyToDistribute,
                'LiquidityPoolManager::addWhitelistedPool: Cannot add pool between calculating and distributing returns');
        require(pair != address(0), 'LiquidityPoolManager::addWhitelistedPool: Pool cannot be the zero address');
        require(isWhitelisted(pair) == false, 'LiquidityPoolManager::addWhitelistedPool: Pool already whitelisted');

        address token0 = IPangolinPair(pair).token0();
        address token1 = IPangolinPair(pair).token1();

        require(token0 != token1, 'LiquidityPoolManager::addWhitelistedPool: Tokens cannot be identical');

        // Create the staking contract and associate it with the pair
        address stakeContract = address(new StakingRewards(png, pair));
        stakes[pair] = stakeContract;

        pngPairs.add(pair);

        numPools = numPools.add(1);
    }

    /**
     * Delists a whitelisted pool. Liquidity providers will not receiving future rewards.
     * Already vested funds can still be claimed. Re-whitelisting a delisted pool will
     * deploy a new staking contract.
     *
     * Args:
     *   pair: pair to remove from whitelist
     */
    function removeWhitelistedPool(address pair) external onlyOwner {
        require(!readyToDistribute,
                'LiquidityPoolManager::removeWhitelistedPool: Cannot remove pool between calculating and distributing returns');
        require(isWhitelisted(pair), 'LiquidityPoolManager::removeWhitelistedPool: Pool not whitelisted');

        address token0 = IPangolinPair(pair).token0();
        address token1 = IPangolinPair(pair).token1();

        stakes[pair] = address(0);

        if (token0 == wavax || token1 == wavax) {
            require(avaxPairs.remove(pair), 'LiquidityPoolManager::removeWhitelistedPool: Pair remove failed');
        } else {
            require(pngPairs.remove(pair), 'LiquidityPoolManager::removeWhitelistedPool: Pair remove failed');
        }
        numPools = numPools.sub(1);
    }

    /**
     * Calculates the amount of liquidity in the pair. For an AVAX pool, the liquidity in the
     * pair is two times the amount of AVAX. Only works for AVAX pairs.
     *
     * Args:
     *   pair: AVAX pair to get liquidity in
     *
     * Returns: the amount of liquidity in the pool in units of AVAX
     */
    function getAvaxLiquidity(address pair) public view returns (uint) {
        (uint reserve0, uint reserve1, ) = IPangolinPair(pair).getReserves();

        uint liquidity = 0;

        // add the avax straight up
        if (IPangolinPair(pair).token0() == wavax) {
            liquidity = liquidity.add(reserve0);
        } else {
            require(IPangolinPair(pair).token1() == wavax, 'LiquidityPoolManager::getAvaxLiquidity: One of the tokens in the pair must be WAVAX');
            liquidity = liquidity.add(reserve1);
        }
        liquidity = liquidity.mul(2);
        return liquidity;
    }

    /**
     * Calculates the amount of liquidity in the pair. For a PNG pool, the liquidity in the
     * pair is two times the amount of PNG multiplied by the price of AVAX per PNG. Only
     * works for PNG pairs.
     *
     * Args:
     *   pair: PNG pair to get liquidity in
     *   conversionFactor: the price of AVAX to PNG
     *
     * Returns: the amount of liquidity in the pool in units of AVAX
     */
    function getPngLiquidity(address pair, uint conversionFactor) public view returns (uint) {
        (uint reserve0, uint reserve1, ) = IPangolinPair(pair).getReserves();

        uint liquidity = 0;

        // add the png straight up
        if (IPangolinPair(pair).token0() == png) {
            liquidity = liquidity.add(reserve0);
        } else {
            require(IPangolinPair(pair).token1() == png, 'LiquidityPoolManager::getPngLiquidity: One of the tokens in the pair must be PNG');
            liquidity = liquidity.add(reserve1);
        }

        uint oneToken = 1e18;
        liquidity = liquidity.mul(conversionFactor).mul(2).div(oneToken);
        return liquidity;
    }
}

interface IPNG {
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint rawAmount) external returns (bool);
}

interface IPangolinPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function factory() external view returns (address);
    function balanceOf(address owner) external view returns (uint);
    function transfer(address to, uint value) external returns (bool);
    function burn(address to) external returns (uint amount0, uint amount1);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
}
