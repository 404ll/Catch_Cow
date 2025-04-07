module catch_that_cow::game;

use catch_that_cow::calf::{Self,CALFTokenCap,CALF};
use std::string::{Self,String};
use sui::{
    event::emit,
    token::{Self, Token,TokenPolicy},
    balance::{Self, Balance},
    };


//=======const=========//
const EPofileExist :u64 = 0;
const ERopeNumberEnough :u64 = 1;
const E_ALREADY_CLAIMED_TODAY: u64 = 2;

//=======Structs=======//
public struct AdminCap has key, store {
    id: UID,
}

public struct Cow has key,store{
    id: UID,
    name: String,
    reward: u64,
    difficulty: u64,
    speed: u64,
}

public struct Rope has key,store{
    id: UID,
    level: u64,
    number: u64
}

public struct Player has key,store{
    id: UID,
    name: String,
    allReward: u64,
    game_number:u64,
    rope: Rope,
    last_mint_token_time: u64
}

public struct State has key{
    id: UID,
    players: vector<address>,
}

public struct Pool<T> has key{
    id: UID,
    balance: Balance<T>
}

public struct CowPool has key,store{
    id: UID,
    cow: Cow
}


//========Events========//

public struct PlayerCreated has copy, drop {
    id: ID,
    name: String,
}


//========Functions=======//
fun init (ctx: &mut TxContext) {
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
    let rope_uid = object::new(ctx);

    let id = player_uid.to_inner();
    assert!(
        !vector::contains(&state.players, &user),
        EPofileExist
    );

    let rope = Rope {
        id: rope_uid,
        level: 1,
        number: 0
    };

    let player = Player {
        id:player_uid,
        name,
        allReward: 0,
        game_number: 0,
        rope,
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

//每次升级花费2个token
public fun upgrade_rope(
    mut payment: Token<CALF>,
    player: &mut Player,
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
    player.rope.level = player.rope.level + 1;
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
public fun add_rope(
    // coin: SUI,
    player: &mut Player,
    ctx: &mut TxContext,
    ){
    assert!(player.rope.number > 4, ERopeNumberEnough);
    player.rope.number = player.rope.number + 1;
}

//========admin========//

public entry fun create_pool<T:drop+store>(
    _: &AdminCap,
    ctx: &mut TxContext,
){
    let pool = Pool<T> {
        id: object::new(ctx),
        balance: balance::zero(),
    };
    transfer::share_object(pool);
}

