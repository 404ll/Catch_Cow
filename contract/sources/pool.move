module catch_that_cow::pool;
use sui::{coin::{Self, Coin},
    balance::{Self, Balance},
    table::{Self, Table},
    event::emit,
    clock::Clock,
};
use std::{
    type_name::{Self, TypeName},
};


//=======Structs=======//
public struct PoolState has key {
    id: UID,
    pools: Table<TypeName, u64>,
}

public struct Pool<phantom T> has key {
    id: UID,
    balance: Balance<T>,
}

public struct AdminCap has key,store{
    id: UID
}

//======Const=======//
const ERROR_POOL_EXISTS: u64 = 1;
const ERROR_INSUFFICIENT_BALANCE: u64 = 2;
const ERROR_POOL_NOT_FOUND: u64 = 3;
//======Events=======//
public struct PoolCreated has copy, drop {
    pool_id: ID,
    coin_type: TypeName,
}

public struct PoolWithdraw has copy, drop {
    pool_id: ID,
    amount: u64,
}

public struct PoolDeposit has copy, drop {
    pool_id: ID,
    amount: u64,
}

//======functions=======//

fun init(ctx: &mut TxContext) {
    
    let state =PoolState {
        id: object::new(ctx),
        pools: table::new(ctx),
    };
    let deployer = ctx.sender();
    // 创建管理员权限凭证
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::public_transfer(admin_cap, deployer);
    transfer::share_object(state);
}

public fun create_pool<T: drop>(_: &AdminCap, ctx: &mut TxContext, state: &mut PoolState) {
    let type_name = type_name::get<T>();
    assert!(!table::contains(&state.pools, type_name), ERROR_POOL_EXISTS);

    let pool = Pool<T> {
        id: object::new(ctx),
        balance: balance::zero(),
    };
    table::add(&mut state.pools, type_name, 0);
    
    emit(PoolCreated {
        pool_id: pool.id.to_inner(),
        coin_type: type_name,
    });
    
    transfer::share_object(pool);
}

public fun withdraw_by_admin<T>(
    _: &AdminCap,
    pool: &mut Pool<T>,
    amount: u64,
    state: &mut PoolState,
    ctx: &mut TxContext
): Coin<T> {
    assert!(balance::value(&pool.balance) >= amount, ERROR_INSUFFICIENT_BALANCE);
    
    let withdraw_balance = balance::split(&mut pool.balance, amount);
    let coin = coin::from_balance(withdraw_balance, ctx);
    let pool_id = pool.id.to_inner(); 
    let type_name = type_name::get<T>();
    assert!(table::contains(&state.pools, type_name), ERROR_POOL_NOT_FOUND);
    let pool_amount = table::borrow_mut(&mut state.pools, type_name);
    *pool_amount = *pool_amount - amount;
    emit(PoolWithdraw {
        pool_id,
        amount,
    });
    
    coin
}

public fun add_to_balance<T>(
    pool: &mut Pool<T>, coin: Coin<T>, state: &mut PoolState
) {
    let amount = coin::value(&coin);
    let balance = coin::into_balance(coin);
    balance::join(&mut pool.balance, balance);
    let pool_id = pool.id.to_inner();
    let type_name = type_name::get<T>();
    assert!(table::contains(&state.pools, type_name), ERROR_POOL_NOT_FOUND);
    let pool_amount = table::borrow_mut(&mut state.pools, type_name);
    *pool_amount = *pool_amount + amount;
    
    emit(PoolDeposit {
        pool_id,
        amount,
    });
}

