module catch_that_cow::calf;

use sui::{
    coin::{Self, TreasuryCap},
    token::{Self, TokenPolicy, Token},
    event::emit,
    url::new_unsafe_from_bytes
};

const DECIMALS: u8 = 0;
const SYMBOLS: vector<u8> = b"CALF";
const NAME: vector<u8> = b"calf";
const DESCRIPTION: vector<u8> = b"Calf Token";
const ICON_URL: vector<u8> = b"https://";  

// ======= Errors =======//
const EInvaildAmount :u64 = 1;

//=======Structs=======//
public struct CALF has drop {}

public struct AdminCap has key, store {
    id: UID,
}

public struct CALFTokenCap has key {
    id: UID,
    cap: TreasuryCap<CALF>,
}

// ======= Functions =======//
fun init(otw: CALF, ctx: &mut TxContext) {
    let deployer = ctx.sender();
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::public_transfer(admin_cap, deployer);

    let (treasury_cap, metadata) = coin::create_currency<CALF>(
        otw,
        DECIMALS,
        SYMBOLS, 
        NAME, 
        DESCRIPTION, 
        option::some(new_unsafe_from_bytes(ICON_URL)), 
        ctx
    );

    let (mut policy, cap) = token::new_policy<CALF>(
        &treasury_cap, ctx
    );

    let token_cap = CALFTokenCap {
        id: object::new(ctx),
        cap: treasury_cap,
    };

    // 授权发送权限
    token::allow(&mut policy, &cap,token::spend_action(), ctx);
    // 授权接收权限
    token ::share_policy<CALF>(policy);
    transfer::share_object(token_cap);
    transfer::public_transfer(cap, deployer);
    transfer::public_freeze_object(metadata);
}

public fun mint(token_cap: &mut CALFTokenCap,amount:u64,ctx:&mut TxContext){
    let calf_token = token::mint(&mut token_cap.cap,amount,ctx);
    let req = token::transfer<CALF>(calf_token, ctx.sender(), ctx);
    token::confirm_with_treasury_cap(&mut token_cap.cap, req, ctx);
}

public fun spend(payment:Token<CALF>,token_prolicy:&mut TokenPolicy<CALF>,amount:u64,ctx:&mut TxContext){
    assert!(token::value<CALF>(&payment) == amount,EInvaildAmount);
    let req = token::spend<CALF>(payment,  ctx);
    token::confirm_request_mut( token_prolicy, req, ctx);
}

public fun mint_and_transfer(token_cap:&mut CALFTokenCap,amount:u64,recipient:address,ctx:&mut TxContext){
    let calf_token = token::mint(&mut token_cap.cap,amount,ctx);
    let req = token::transfer<CALF>(calf_token, recipient, ctx);
    token::confirm_with_treasury_cap(&mut token_cap.cap, req, ctx);
    
}