// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPulseXFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}