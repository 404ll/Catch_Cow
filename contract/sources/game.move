module catch_that_cow::game;

use catch_that_cow::calf::{Self,CALFTokenCap,CALF};
use std::string::{Self,String};
use sui::{
    event::emit,
    token::{Self, Token,TokenPolicy},
    coin::{Self, Coin},
    sui::SUI,
    random::{Self, Random},
    };
use catch_that_cow::pool::{Pool,PoolState, add_to_balance};

//=======const=========//
const EPofileExist :u64 = 0;
const ERopeNumberEnough :u64 = 1;
const E_ALREADY_CLAIMED_TODAY: u64 = 2;


//=======Structs=======//
// One-Time-Witness for the module
public struct GAME has drop {}

public struct AdminCap has key, store {
    id: UID,
}

public struct Player has key,store{
    id: UID,
    name: String,
    allReward: u64,
    game_number:u64,
    rope_number: u64,
    last_mint_token_time: u64
}

public struct State has key{
    id: UID,
    players: vector<address>,
}


//========Events========//

public struct PlayerCreated has copy, drop {
    id: ID,
    name: String,
}

/*
reward:1-15,
difficulty:1-4,
*/
public struct RewardEvent has copy, drop {
    token_reward: u64,
    timestamp: u64
}

//========Functions=======//
fun init (_: GAME,ctx: &mut TxContext) {
    let deployer = ctx.sender();
    // 创建管理员权限凭证
    let admin_cap = AdminCap { id: object::new(ctx) };
    // 创建游戏状态
    let state = State {
        id: object::new(ctx),
        players: vector::empty(),
    };
    transfer::public_transfer(admin_cap, deployer);
    transfer::share_object(state);
}

//创建玩家
public entry fun create_player(
    state: &mut State,
    name: String,
    token_cap: &mut CALFTokenCap,
    ctx: &mut TxContext
    ){
    let user = tx_context::sender(ctx);
    let player_uid = object::new(ctx);

    let id = player_uid.to_inner();
    assert!(
        !vector::contains(&state.players, &user),
        EPofileExist
    );

    let player = Player {
        id:player_uid,
        name,
        allReward: 0,
        game_number: 0,
        rope_number: 0,
        last_mint_token_time: tx_context::epoch_timestamp_ms(ctx)
    };
    transfer::transfer(player, user);
    vector::push_back(&mut state.players, user);
    // mint token
    calf::mint(token_cap, 4, ctx);
    emit (PlayerCreated {
        id: id,
        name
    });
}

//==========player========//

//TODO
/* 按下N次按钮就调用一次这个函数？
    使用Token还是仅仅每次消耗gas?
 */

//每次升级花费1个token
public fun upgrade_rope(
    mut payment: Token<CALF>,
    token_policy: &mut TokenPolicy<CALF>,
    ctx: &mut TxContext,
    ){
    let sender = tx_context::sender(ctx);
    // 分割出2个token作为支付，剩余的返还给用户
    let payment_value = token::value(&payment);
    if (payment_value > 1) {
            let remaining = token::split(
                &mut payment,
                payment_value - 2,
                ctx
            );
            token::keep(remaining, ctx);
        };

    // 支付 token
    calf::spend(payment, token_policy, 2, ctx);
}

//每日领取Token
public fun daily_claim(
    player: &mut Player,
    token_cap: &mut CALFTokenCap,
    ctx: &mut TxContext,
    ){
    let user = tx_context::sender(ctx);
    // 检查是否已经领取过
    let current_time = tx_context::epoch_timestamp_ms(ctx);
    assert!(
            player.last_mint_token_time  > current_time,
            E_ALREADY_CLAIMED_TODAY
        );
    // 更新最后领取时间
    player.last_mint_token_time = current_time;
    // mint token
    calf::mint(token_cap, 4, ctx);
}

//每次增加套绳花费0.5个Coin
public fun add_rope<T>(
    payment: &mut Coin<T>,
    player: &mut Player,
    pool: &mut Pool<T>,
    pool_state: &mut PoolState,
    ctx: &mut TxContext,
    ){
    assert!(player.rope_number < 3, ERopeNumberEnough);
    let amount = 1/2;
    let into_coin = coin::split(payment, amount, ctx);

    add_to_balance(pool, into_coin,pool_state);
    player.rope_number = player.rope_number + 1;
}

//======game======//

//TODO
/*针对每次出绳的战斗*/
public entry fun random_battle(
    player: &mut Player,
    token_cap: &mut CALFTokenCap,
    random: &Random,
    ctx: &mut TxContext
) {
    // 获取当前时间戳
    let current_time = tx_context::epoch_timestamp_ms(ctx);

    // 动态调整奖励范围
    let base_reward = 1 + player.rope_number; // 最小奖励随套绳数量增加
    let max_reward = 5 ; // 最大奖励随套绳数量增加

    // 动态调整难度
    let difficulty = 3 + player.rope_number; // 难度随套绳数量增加

    // 创建随机数生成器
    let mut rand_generator = random::new_generator(random, ctx);
    // 生成随机数
    let random_value = random::generate_u64_in_range(&mut rand_generator, 0, 100); // 生成 0-99 的随机数

    // 根据随机数判断战斗结果
    let success_threshold = 35 + difficulty * 5; // 难度越高，成功阈值越高,获奖的基础概率为50
    let is_success = random_value > success_threshold;

    // 根据战斗结果和随机数分配奖励
    let token_reward = if (!is_success) {
        0 // 如果战斗失败，奖励为 0
        } else if (random_value < 40) {
            base_reward // 40% 概率只获得基础奖励
        } else if (random_value < 70 ){
            // 30%动态生成奖励值，范围在 base_reward 到 max_reward 之间
            random::generate_u64_in_range(&mut rand_generator, base_reward, max_reward)
        } else if (random_value < 90) {
            base_reward + difficulty * 2 // 20% 概率获得更高奖励
        } else {
            max_reward + player.rope_number// 10% 概率获得最大奖励
    };

    // mint 奖励 token（仅当奖励大于 0 时）
    if (token_reward > 0) {
        calf::mint(token_cap, token_reward, ctx);
    };

    // 更新玩家状态
    player.allReward = player.allReward + token_reward;
    player.game_number = player.game_number + 1;

    // 重置玩家的套绳数量为 1
    player.rope_number = 1;
    // 触发奖励事件
    emit(RewardEvent {
        token_reward,
        timestamp: current_time,
    });
}