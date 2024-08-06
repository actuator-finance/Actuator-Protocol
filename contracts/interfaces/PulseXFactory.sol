// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPulseXFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}