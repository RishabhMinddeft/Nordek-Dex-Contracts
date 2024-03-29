pragma solidity =0.6.6;

import './libraries/TransferHelper.sol';

import './interfaces/INordekV2Router02.sol';
import './libraries/NordekRouterV2Library.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWNRK.sol';
import './interfaces/INordekV2Factory.sol';

contract NordekRouterV2 {
    using SafeMath for uint;

    address public immutable factory;
    address public immutable WNRK;

    bytes constant MAIN_PAIR_INIT_CODE =
        hex'bdb1434088c80e45d539942c49b70ecb478982edf71902719a57dcbf9e1d033f';

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'NordekV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WNRK) public {
        factory = _factory;
        WNRK = _WNRK;
    }

    receive() external payable {
        assert(msg.sender == WNRK); // only accept NRK via fallback from the WNRK contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (INordekV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            INordekV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = NordekRouterV2Library.getReserves(
            factory,
            tokenA,
            tokenB,
            MAIN_PAIR_INIT_CODE
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = NordekRouterV2Library.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    'NordekV2Router: INSUFFICIENT_B_AMOUNT'
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = NordekRouterV2Library.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    'NordekV2Router: INSUFFICIENT_A_AMOUNT'
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        ensure(deadline)
        returns (uint amountA, uint amountB, uint liquidity)
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = NordekRouterV2Library.pairFor(
            factory,
            tokenA,
            tokenB,
            MAIN_PAIR_INIT_CODE
        );
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = INordekV2Pair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint amountToken, uint amountETH, uint liquidity)
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WNRK,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = NordekRouterV2Library.pairFor(
            factory,
            token,
            WNRK,
            MAIN_PAIR_INIT_CODE
        );
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWNRK(WNRK).deposit{value: amountETH}();
        assert(IWNRK(WNRK).transfer(pair, amountETH));
        liquidity = INordekV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH)
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = NordekRouterV2Library.pairFor(
            factory,
            tokenA,
            tokenB,
            MAIN_PAIR_INIT_CODE
        );
        INordekV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = INordekV2Pair(pair).burn(to);
        (address token0, ) = NordekRouterV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(amountA >= amountAMin, 'NordekV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'NordekV2Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WNRK,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWNRK(WNRK).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB) {
        address pair = NordekRouterV2Library.pairFor(
            factory,
            tokenA,
            tokenB,
            MAIN_PAIR_INIT_CODE
        );
        uint value = approveMax ? uint(-1) : liquidity;
        INordekV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH) {
        address pair = NordekRouterV2Library.pairFor(
            factory,
            token,
            WNRK,
            MAIN_PAIR_INIT_CODE
        );
        uint value = approveMax ? uint(-1) : liquidity;
        INordekV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WNRK,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IERC20(token).balanceOf(address(this))
        );
        IWNRK(WNRK).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH) {
        address pair = NordekRouterV2Library.pairFor(
            factory,
            token,
            WNRK,
            MAIN_PAIR_INIT_CODE
        );
        uint value = approveMax ? uint(-1) : liquidity;
        INordekV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = NordekRouterV2Library.sortTokens(
                input,
                output
            );
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOut)
                : (amountOut, uint(0));
            address to = i < path.length - 2
                ? NordekRouterV2Library.pairFor(
                    factory,
                    output,
                    path[i + 2],
                    MAIN_PAIR_INIT_CODE
                )
                : _to;
            INordekV2Pair(
                NordekRouterV2Library.pairFor(
                    factory,
                    input,
                    output,
                    MAIN_PAIR_INIT_CODE
                )
            ).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        amounts = NordekRouterV2Library.getAmountsOut(
            factory,
            amountIn,
            path,
            MAIN_PAIR_INIT_CODE
        );
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            'NordekV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            NordekRouterV2Library.pairFor(
                factory,
                path[0],
                path[1],
                MAIN_PAIR_INIT_CODE
            ),
            amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        amounts = NordekRouterV2Library.getAmountsIn(
            factory,
            amountOut,
            path,
            MAIN_PAIR_INIT_CODE
        );
        require(
            amounts[0] <= amountInMax,
            'NordekV2Router: EXCESSIVE_INPUT_AMOUNT'
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            NordekRouterV2Library.pairFor(
                factory,
                path[0],
                path[1],
                MAIN_PAIR_INIT_CODE
            ),
            amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WNRK, 'NordekV2Router: INVALID_PATH');
        amounts = NordekRouterV2Library.getAmountsOut(
            factory,
            msg.value,
            path,
            MAIN_PAIR_INIT_CODE
        );
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            'NordekV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        IWNRK(WNRK).deposit{value: amounts[0]}();
        assert(
            IWNRK(WNRK).transfer(
                NordekRouterV2Library.pairFor(
                    factory,
                    path[0],
                    path[1],
                    MAIN_PAIR_INIT_CODE
                ),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WNRK, 'NordekV2Router: INVALID_PATH');
        amounts = NordekRouterV2Library.getAmountsIn(
            factory,
            amountOut,
            path,
            MAIN_PAIR_INIT_CODE
        );
        require(
            amounts[0] <= amountInMax,
            'NordekV2Router: EXCESSIVE_INPUT_AMOUNT'
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            NordekRouterV2Library.pairFor(
                factory,
                path[0],
                path[1],
                MAIN_PAIR_INIT_CODE
            ),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWNRK(WNRK).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WNRK, 'NordekV2Router: INVALID_PATH');
        amounts = NordekRouterV2Library.getAmountsOut(
            factory,
            amountIn,
            path,
            MAIN_PAIR_INIT_CODE
        );
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            'NordekV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            NordekRouterV2Library.pairFor(
                factory,
                path[0],
                path[1],
                MAIN_PAIR_INIT_CODE
            ),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWNRK(WNRK).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WNRK, 'NordekV2Router: INVALID_PATH');
        amounts = NordekRouterV2Library.getAmountsIn(
            factory,
            amountOut,
            path,
            MAIN_PAIR_INIT_CODE
        );
        require(
            amounts[0] <= msg.value,
            'NordekV2Router: EXCESSIVE_INPUT_AMOUNT'
        );
        IWNRK(WNRK).deposit{value: amounts[0]}();
        assert(
            IWNRK(WNRK).transfer(
                NordekRouterV2Library.pairFor(
                    factory,
                    path[0],
                    path[1],
                    MAIN_PAIR_INIT_CODE
                ),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = NordekRouterV2Library.sortTokens(
                input,
                output
            );
            INordekV2Pair pair = INordekV2Pair(
                NordekRouterV2Library.pairFor(
                    factory,
                    input,
                    output,
                    MAIN_PAIR_INIT_CODE
                )
            );
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(
                    reserveInput
                );
                amountOutput = NordekRouterV2Library.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOutput)
                : (amountOutput, uint(0));
            address to = i < path.length - 2
                ? NordekRouterV2Library.pairFor(
                    factory,
                    output,
                    path[i + 2],
                    MAIN_PAIR_INIT_CODE
                )
                : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            NordekRouterV2Library.pairFor(
                factory,
                path[0],
                path[1],
                MAIN_PAIR_INIT_CODE
            ),
            amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            'NordekV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable ensure(deadline) {
        require(path[0] == WNRK, 'NordekV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWNRK(WNRK).deposit{value: amountIn}();
        assert(
            IWNRK(WNRK).transfer(
                NordekRouterV2Library.pairFor(
                    factory,
                    path[0],
                    path[1],
                    MAIN_PAIR_INIT_CODE
                ),
                amountIn
            )
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            'NordekV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) {
        require(path[path.length - 1] == WNRK, 'NordekV2Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            NordekRouterV2Library.pairFor(
                factory,
                path[0],
                path[1],
                MAIN_PAIR_INIT_CODE
            ),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WNRK).balanceOf(address(this));
        require(
            amountOut >= amountOutMin,
            'NordekV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        IWNRK(WNRK).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }
}
