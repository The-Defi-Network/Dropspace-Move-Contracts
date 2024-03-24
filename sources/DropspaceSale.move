module dropspace::NFTForSale {
    use std::signer::{Self};
    use std::string::{Self, String};
    use std::vector;
    use std::debug;

    use aptos_token::token;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin::{Self};
    use aptos_framework::event;

    const DROPSPACE_FEE: u64 = 125000; // 0.125 Aptos in micro-units
    const UINT64_MAX: u64 = 18446744073709551615; // Max value of u64

    // Error code constants
    const ERROR_INVALID_TIME: u64 = 9999;
    const ERROR_INVALID_QUANTITY: u64 = 8888;
    const ERROR_EXCEEDS_TOTAL_SUPPLY: u64 = 7777;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 6666;
    const ERROR_UNAUTHORIZED: u64 = 5555;
    const ERROR_INVALID_TOTAL_SUPPLY: u64 = 4444;

    // Structure representing the NFT sale
    struct NFTForSale has key {
        name: String,
        ticker: String,
        mint_per_tx: u64,
        mint_price: u64,
        mint_fee: u64,
        supply_limit: u64,
        withdraw_wallet: address,
        dev_wallet: address,
        sale_time: u64,
        next_id: u64,
        total_sold: u64,
        base_uri: String,
    }

    #[event]
    /// Event representing a change to the marketplace configuration
    struct NFTForSaleEvent has drop, store {
        account: address,
        /// The type info of the struct that was updated.
        updated_event: String,
    }

    // Initialize the NFT sale
    public fun init_nft_sale(account: &signer, name: String, ticker: String, mint_per_tx: u64, mint_price: u64, mint_fee: u64, supply_limit: u64, withdraw_wallet: address, dev_wallet: address, sale_time: u64, base_uri: String) {
        let nft_sale_data = NFTForSale {
            name: name, 
            ticker: ticker,
            mint_per_tx: mint_per_tx,
            mint_price: mint_price,
            mint_fee: mint_fee,
            supply_limit: supply_limit,
            withdraw_wallet: withdraw_wallet,
            dev_wallet: dev_wallet,
            sale_time: sale_time,
            next_id: 0,
            total_sold: 0,
            base_uri: base_uri,
        };
        move_to(account, nft_sale_data);
    }

    fun num_str(x: u64): vector<u8> {
        // Initialize an empty vector of u8 values
        let s = vector::empty<u8>();

        // Check if the int is zero
        if (x == 0) {
        // Append the ASCII value of '0' to the vector
            vector::push_back(&mut s, 48);
            // Return the vector
            s
        } else {

            // Initialize a mutable copy of the int
            let x_copy = x;

            // Loop until the int is zero
            while (x_copy > 0) {
                // Get the remainder of the int divided by 10
                let r = x_copy % 10;
                // Subtract the remainder from the int
                x_copy = x_copy - r;
                // Divide the int by 10
                x_copy = x_copy / 10;
                // Convert the remainder to an ASCII value by adding 48
                let c: u8 = (r as u8) + 48;
                // Prepend the ASCII value to the vector
                vector::push_back(&mut s, c);
            };

            // Return the vector
            s
        }
    }

    // Purchase NFTs
    public entry fun buy(account: &signer, buyer: &signer, quantity: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));

        // Validate purchase conditions
        let now = timestamp::now_microseconds();
        assert!(now >= nft_sale.sale_time, ERROR_INVALID_TIME); // Invalid time
        assert!(quantity > 0 && quantity <= nft_sale.mint_per_tx, ERROR_INVALID_QUANTITY); // Invalid quantity
        assert!(nft_sale.total_sold + quantity <= nft_sale.supply_limit, ERROR_EXCEEDS_TOTAL_SUPPLY); // Exceeds total supply

        // Calculate payments
        let dropspace_payment = nft_sale.mint_fee * quantity;
        let owner_payment = nft_sale.mint_price * quantity - dropspace_payment;
        debug::print(&owner_payment);
        debug::print(&dropspace_payment);
        // Check if the buyer has enough funds
        let total_price = nft_sale.mint_price * quantity;
        let buyer_balance = coin::balance<AptosCoin>(signer::address_of(buyer));
        debug::print(&buyer_balance);
        assert!(buyer_balance >= total_price, ERROR_INSUFFICIENT_FUNDS); // Insufficient funds

        // Transfer funds to dev wallet and owner wallet
        coin::transfer<AptosCoin>(buyer, nft_sale.dev_wallet, dropspace_payment);
        coin::transfer<AptosCoin>(buyer, nft_sale.withdraw_wallet, owner_payment);

        // Mint NFTs
        mint_nft(account, buyer, quantity, nft_sale);

        // Update total sold
        nft_sale.total_sold = nft_sale.total_sold + quantity;
    }

    // Mint Token
    fun mint_nft(account: &signer, buyer: &signer, quantity: u64, nft_sale: &mut NFTForSale) {
        let i = 0;
        //create collection
        let mutate_setting = vector<bool>[ false, false, false ];
        token::create_collection(account, nft_sale.ticker, string::utf8(b""), nft_sale.base_uri, nft_sale.supply_limit, mutate_setting);

        //create mint for quantity
        while (i < quantity) {
            let metadata_uri = nft_sale.base_uri;
            let mint_position = nft_sale.next_id;
            string::append(&mut metadata_uri,string::utf8(b"/"));
            string::append(&mut metadata_uri,string::utf8(num_str(mint_position)));
            string::append(&mut metadata_uri,string::utf8(b".json"));

            // nft::mint(account, metadata_uri, owner); // Mint function in the NFT module
            let token_data_id = token::create_tokendata(
                account,
                nft_sale.ticker, //collection_name
                nft_sale.name, //token_name
                string::utf8(b""),
                0,
                metadata_uri,
                signer::address_of(account),
                1,
                0,
                // This variable sets if we want to allow mutation for token maximum, uri, royalty, description, and properties.
                // Here we enable mutation for properties by setting the last boolean in the vector to true.
                token::create_token_mutability_config(
                    &vector<bool>[ false, false, false, false, true ]
                ),
                // We can use property maps to record attributes related to the token.
                // In this example, we are using it to record the receiver's address.
                // We will mutate this field to record the user's address
                // when a user successfully mints a token in the `mint_nft()` function.
                vector<String>[string::utf8(b"given_to")],
                vector<vector<u8>>[b""],
                vector<String>[string::utf8(b"address") ],
            );
            let token_id = token::mint_token(account, token_data_id, 1);
            token::direct_transfer(account, buyer, token_id, 1);
            nft_sale.next_id = nft_sale.next_id + 1;
            i= i + 1;
        };
    }

    // Function to view current NFT sale status
    #[view]
    public fun view_nft_sale_status(owner: address): (u64, u64, u64, u64, u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.next_id, nft_sale.total_sold, nft_sale.supply_limit, nft_sale.mint_per_tx, nft_sale.mint_price)
    }
    
    // Function to get current NFT Name
    #[view]
    public fun get_name(owner: address): (String) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.name)
    }

    // Function to get current NFT ticker
    #[view]
    public fun get_ticker(owner: address): (String) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.ticker)
    }

    // Function to get current mint price
    #[view]
    public fun get_mint_price(owner: address): (u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.mint_price)
    }
    
    // Function to get current mint fee
    #[view]
    public fun get_mint_fee(owner: address): (u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.mint_fee)
    }

    #[view]
    public fun get_supply_limit(owner: address): (u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.supply_limit)
    }

    // Function to get current total supply
    #[view]
    public fun get_total_supply(owner: address): (u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.total_sold)
    }

    // Function to get current withdraw_wallet
    #[view]
    public fun get_withdraw_wallet(owner: address): (address) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.withdraw_wallet)
    }

    // Function to get current get_sale_time
    #[view]
    public fun get_sale_time(owner: address): (u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.sale_time)
    }

    // Function to get current get_owner
    #[view]
    public fun get_owner(owner: address): (address) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.withdraw_wallet)
    }

    // Function to modify the price per NFT
    public entry fun modify_mint_price(account: &signer, new_price: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.mint_price = new_price;
        let updated_resource = string::utf8(b"modify_mint_price");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Function to modify the max NFTs per transaction
    public entry fun modify_mint_per_tx(account: &signer, new_max: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.mint_per_tx = new_max;
        let updated_resource = string::utf8(b"modify_mint_per_tx");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Function to modify the total supply
    public entry fun modify_supply_limit(account: &signer, new_supply_limit: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        assert!(new_supply_limit >= nft_sale.total_sold, ERROR_INVALID_TOTAL_SUPPLY); // Invalid total supply
        nft_sale.supply_limit = new_supply_limit;
        let updated_resource = string::utf8(b"modify_supply_limit");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Function to modify the sale start time
    public entry fun modify_sale_time(account: &signer, new_start: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.sale_time = new_start;
        let updated_resource = string::utf8(b"modify_sale_time");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Function to modify the base URI
    public entry fun modify_base_uri(account: &signer, new_base_uri: String) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.base_uri = new_base_uri;
        let updated_resource = string::utf8(b"modify_base_uri");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Toggle function for sale_time
    public entry fun toggle_sale_time(account: &signer) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized

        let now = timestamp::now_microseconds();
        if (nft_sale.sale_time <= now) {
            nft_sale.sale_time = UINT64_MAX;
        } else {
            nft_sale.sale_time = 0;
        }
    }

    // Function to modify the withdraw wallet
    public entry fun modify_withdraw_wallet(account: &signer, new_withdraw_wallet: address) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));

        // Ensure only the contract owner can modify the owner wallet
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized

        // Update the owner wallet address
        nft_sale.withdraw_wallet = new_withdraw_wallet;
        let updated_resource = string::utf8(b"modify_withdraw_wallet");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }
    // Function to modify the name
    public entry fun modify_name(account: &signer, new_name: String) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.name = new_name;
        let updated_resource = string::utf8(b"modify_name");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Function to modify the ticker
    public entry fun modify_ticker(account: &signer, new_ticker: String) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.ticker = new_ticker;
        let updated_resource = string::utf8(b"modify_ticker");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    // Function to modify the fee per NFT
    public entry fun modify_mint_fee(account: &signer, new_fee: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.mint_fee = new_fee;
        let updated_resource = string::utf8(b"modify_mint_fee");
        event::emit(NFTForSaleEvent { account: signer::address_of(account), updated_event: updated_resource});
    }

    #[test(account = @0x1)]
    fun test_init_for_sale(account: &signer) acquires NFTForSale {
        init_nft_sale(account, string::utf8(b"test_name"), string::utf8(b"test_ticker"), 10, 1, 1, 100, @0x1, @0x111, 0, string::utf8(b"test_uri"));

        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));

        assert!(nft_sale.next_id == 0, 0);
        assert!(nft_sale.total_sold == 0, 0);
        assert!(nft_sale.supply_limit == 100, 0);
        assert!(nft_sale.mint_per_tx == 10, 0);
        assert!(nft_sale.mint_price == 1, 0);
        assert!(nft_sale.sale_time == 0, 0);
        assert!(nft_sale.base_uri == string::utf8(b"test_uri"), 0);
        assert!(nft_sale.dev_wallet == @0x111,0 );
        assert!(nft_sale.withdraw_wallet == @0x1, 0);
        assert!(nft_sale.name == string::utf8(b"test_name"), 0);
        assert!(nft_sale.ticker == string::utf8(b"test_ticker"), 0);
    }

    #[test_only]
    public inline fun setup(
        owner: &signer,
        seller: &signer,
        dev_wallet: &signer
    ): (address, address, address) {
        timestamp::set_time_has_started_for_testing(owner);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(owner);

        let owner_addr = signer::address_of(owner);
        account::create_account_for_test(owner_addr);
        coin::register<AptosCoin>(owner);

        //create for dev wallet 

        let dev_wallet_addr = signer::address_of(dev_wallet);
        account::create_account_for_test(dev_wallet_addr);
        coin::register<AptosCoin>(dev_wallet);

        let seller_addr = signer::address_of(seller);
        account::create_account_for_test(seller_addr);
        coin::register<AptosCoin>(seller);


        let coins = coin::mint(10000, &mint_cap);
        coin::deposit(seller_addr, coins);

        // let coins = coin::mint(10000, &mint_cap);
        // coin::deposit(owner_addr, coins);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        (owner_addr, seller_addr, dev_wallet_addr)
    }

    #[test(account = @0x1, seller = @0x222, dev_wallet = @0x111)]
    fun test_buy(account: &signer, seller: &signer, dev_wallet: &signer) acquires NFTForSale {
        init_nft_sale(account, string::utf8(b"test_name"), string::utf8(b"test_ticker"), 10, 10, 1, 100, @0x1, signer::address_of(dev_wallet), 0, string::utf8(b"test_uri"));
        let (_, _, _) = setup(account, seller, dev_wallet);
        buy(account, seller, 1);
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));

        //get for funds dev_wallet_balance
        let dev_wallet_balance = coin::balance<AptosCoin>(nft_sale.dev_wallet);
        assert!(dev_wallet_balance == 1, 0);
        
        //get for funds owner_wallet_balance
        let withdraw_wallet_balance = coin::balance<AptosCoin>(nft_sale.withdraw_wallet);
        assert!(withdraw_wallet_balance == 9, 0);

        //get for assert funds
        assert!(nft_sale.next_id == 1, 0);
    }

    #[test(account = @0x1, dev_wallet = @0x111)]
    fun test_view_nft_sale_status(account: &signer, dev_wallet: &signer) acquires NFTForSale {
        init_nft_sale(account, string::utf8(b"test_name"), string::utf8(b"test_ticker"), 10, 10, 1, 100, @0x1, signer::address_of(dev_wallet), 0, string::utf8(b"test_uri"));
        let (next_id, total_sold, supply_limit, mint_per_tx, mint_price) = view_nft_sale_status(signer::address_of(account));
        
        assert!(next_id == 0, 0);
        assert!(total_sold == 0, 0);
        assert!(supply_limit == 100, 0);
        assert!(mint_per_tx == 10, 0);
        assert!(mint_price == 10, 0);

    }

    #[test(account = @0x1, dev_wallet = @0x111)]
    fun test_modify_mint_fee(account: &signer, dev_wallet: &signer) acquires NFTForSale {
        init_nft_sale(account, string::utf8(b"test_name"), string::utf8(b"test_ticker"), 10, 10, 1, 100, @0x1, signer::address_of(dev_wallet), 0, string::utf8(b"test_uri"));
        modify_mint_fee(account, 1000);
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(nft_sale.mint_fee == 1000, 0);
    }

}
