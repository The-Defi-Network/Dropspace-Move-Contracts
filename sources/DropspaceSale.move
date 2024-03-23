module dropspace::NFTForSale {
    use std::signer::{Self};
    use std::string::{Self, String};
    use std::vector;
    use aptos_token::token;

    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self};

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
        let dropspace_payment = DROPSPACE_FEE * quantity;
        let owner_payment = nft_sale.mint_price * quantity - dropspace_payment;

        // Check if the buyer has enough funds
        let total_price = nft_sale.mint_price * quantity;
        let buyer_balance = coin::balance<AptosCoin>(signer::address_of(buyer));
        assert!(buyer_balance >= total_price, ERROR_INSUFFICIENT_FUNDS); // Insufficient funds

        // Transfer funds to dev wallet and owner wallet
        coin::transfer<AptosCoin>(account, nft_sale.dev_wallet, dropspace_payment);
        coin::transfer<AptosCoin>(account, nft_sale.withdraw_wallet, owner_payment);

        // Mint NFTs
        mint_nft(account, buyer, quantity, nft_sale);

        // Update total sold
        nft_sale.total_sold = nft_sale.total_sold + quantity;
    }

    // Mint Token
    fun mint_nft(account: &signer, buyer: &signer, quantity: u64, nft_sale: &mut NFTForSale) {
        let i = 0;
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
    }

    // Function to modify the max NFTs per transaction
    public entry fun modify_mint_per_tx(account: &signer, new_max: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.mint_per_tx = new_max;
    }

    // Function to modify the total supply
    public entry fun modify_supply_limit(account: &signer, new_supply_limit: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        assert!(new_supply_limit >= nft_sale.total_sold, ERROR_INVALID_TOTAL_SUPPLY); // Invalid total supply
        nft_sale.supply_limit = new_supply_limit;
    }

    // Function to modify the sale start time
    public entry fun modify_sale_time(account: &signer, new_start: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.sale_time = new_start;
    }

    // Function to modify the base URI
    public entry fun modify_base_uri(account: &signer, new_base_uri: String) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.base_uri = new_base_uri;
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
    }
    // Function to modify the name
    public entry fun set_name(account: &signer, new_name: String) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.name = new_name;
    }

    // Function to modify the ticker
    public entry fun set_ticker(account: &signer, new_ticker: String) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.ticker = new_ticker;
    }

    // Function to modify the fee per NFT
    public entry fun modify_mint_fee(account: &signer, new_fee: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(signer::address_of(account));
        assert!(signer::address_of(account) == nft_sale.withdraw_wallet, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.mint_fee = new_fee;
    }
}
