module dropspace::NFTForSale {
    use std::signer::{Self};
    use std::string::{Self, String};
    use std::vector;
    use aptos_token::token;
    use aptos_token::token::TokenDataId;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    // use aptos_framework::nft::{Self, NFT};

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
        next_id: u64,
        total_sold: u64,
        total_supply: u64,
        max_nfts_per_tx: u64,
        price_per_nft: u64,
        sale_start: u64,
        base_uri: vector<u8>,
        dev_wallet: address,
        owner_wallet: address,
    }

    // Initialize the NFT sale
    public fun init_nft_sale(account: &signer, total_supply: u64, max_nfts_per_tx: u64, price_per_nft: u64, sale_start: u64, base_uri: vector<u8>, dev_wallet: address, owner_wallet: address) {
        let nft_sale_data = NFTForSale {
            next_id: 0,
            total_sold: 0,
            total_supply: total_supply,
            max_nfts_per_tx: max_nfts_per_tx,
            price_per_nft: price_per_nft,
            sale_start: sale_start,
            base_uri: base_uri,
            dev_wallet: dev_wallet,
            owner_wallet: owner_wallet,
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
    public entry fun purchase_nft(account: &signer, owner: address, quantity: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);

        // Validate purchase conditions
        let now = timestamp::now_microseconds();
        assert!(now >= nft_sale.sale_start, ERROR_INVALID_TIME); // Invalid time
        assert!(quantity > 0 && quantity <= nft_sale.max_nfts_per_tx, ERROR_INVALID_QUANTITY); // Invalid quantity
        assert!(nft_sale.total_sold + quantity <= nft_sale.total_supply, ERROR_EXCEEDS_TOTAL_SUPPLY); // Exceeds total supply

        // Calculate payments
        let dropspace_payment = DROPSPACE_FEE * quantity;
        let owner_payment = nft_sale.price_per_nft * quantity - dropspace_payment;

        // Check if the buyer has enough funds
        let total_price = nft_sale.price_per_nft * quantity;
        let buyer_balance = coin::balance<AptosCoin>(owner);
        assert!(buyer_balance >= total_price, ERROR_INSUFFICIENT_FUNDS); // Insufficient funds

        // Transfer funds to dev wallet and owner wallet
        coin::transfer<AptosCoin>(account, nft_sale.dev_wallet, dropspace_payment);
        coin::transfer<AptosCoin>(account, nft_sale.owner_wallet, owner_payment);

        // Mint NFTs
        let i = 0;
        while (i < quantity) {
            let metadata_uri = string::utf8(nft_sale.base_uri);
            let mint_position = nft_sale.next_id;
            string::append(&mut metadata_uri,string::utf8(b"/"));
            string::append(&mut metadata_uri,string::utf8(num_str(mint_position)));
            string::append(&mut metadata_uri,string::utf8(b".json"));

            // nft::mint(account, metadata_uri, owner); // Mint function in the NFT module
            let token_data_id = token::create_tokendata(
                account,
                string::utf8(b""), //collection_name
                string::utf8(b""), //token_name
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
                vector<String>[ string::utf8(b"address") ],
            );
            let token_id = token::mint_token(account, token_data_id, 1);
            token::direct_transfer(account, account, token_id, 1);
            nft_sale.next_id = nft_sale.next_id + 1;
            i= i + 1;
        };

        // Update total sold
        nft_sale.total_sold = nft_sale.total_sold + quantity;
    }

    // Function to view current NFT sale status
    #[view]
    public fun view_nft_sale_status(owner: address): (u64, u64, u64, u64, u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.next_id, nft_sale.total_sold, nft_sale.total_supply, nft_sale.max_nfts_per_tx, nft_sale.price_per_nft)
    }

    // Function to modify the price per NFT
    public entry fun modify_price_per_nft(account: &signer, owner: address, new_price: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.price_per_nft = new_price;
    }

    // Function to modify the max NFTs per transaction
    public entry fun modify_max_nfts_per_tx(account: &signer, owner: address, new_max: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.max_nfts_per_tx = new_max;
    }

    // Function to modify the total supply
    public entry fun modify_total_supply(account: &signer, owner: address, new_total_supply: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized
        assert!(new_total_supply >= nft_sale.total_sold, ERROR_INVALID_TOTAL_SUPPLY); // Invalid total supply
        nft_sale.total_supply = new_total_supply;
    }

    // Function to modify the sale start time
    public entry fun modify_sale_start(account: &signer, owner: address, new_start: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.sale_start = new_start;
    }

    // Function to modify the base URI
    public entry fun modify_base_uri(account: &signer, owner: address, new_base_uri: vector<u8>) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized
        nft_sale.base_uri = new_base_uri;
    }

    // Toggle function for sale_start
    public entry fun toggle_sale_start(account: &signer, owner: address) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized

        let now = timestamp::now_microseconds();
        if (nft_sale.sale_start <= now) {
            nft_sale.sale_start = UINT64_MAX;
        } else {
            nft_sale.sale_start = 0;
        }
    }

    // Function to modify the owner wallet
    public entry fun modify_owner_wallet(account: &signer, owner: address, new_owner_wallet: address) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);

        // Ensure only the contract owner can modify the owner wallet
        assert!(signer::address_of(account) == owner, ERROR_UNAUTHORIZED); // Unauthorized

        // Update the owner wallet address
        nft_sale.owner_wallet = new_owner_wallet;
    }

    // Tests

    // Test initialization of the NFT sale
    #[test]
    public fun test_init_nft_sale() {
        // Define test signer
        let test_account = signer::create_signer(@0x1);

        // Call init_nft_sale with test parameters
        init_nft_sale(&test_account, 100, 5, 1000, 0, b"test_uri", @0x2, @0x3);

        // Assertions to check if the sale was initialized correctly
        let nft_sale = borrow_global<NFTForSale>(@0x3);
        assert!(nft_sale.next_id == 0);
        assert!(nft_sale.total_sold == 0);
        assert!(nft_sale.total_supply == 100);
        assert!(nft_sale.max_nfts_per_tx == 5);
        assert!(nft_sale.price_per_nft == 1000);
        assert!(nft_sale.sale_start == 0);
        assert!(nft_sale.base_uri == b"test_uri");
        assert!(nft_sale.dev_wallet == @0x2);
        assert!(nft_sale.owner_wallet == @0x3);
    }

    // Test purchase of NFTs
    #[test]
    public fun test_purchase_nft() {
        // Setup test environment and accounts
        let test_account = signer::create_signer(@0x1);

        // Initialize NFT sale
        init_nft_sale(&test_account, 100, 5, 1000, 0, b"test_uri", @0x2, @0x3);
   
        // Attempt to purchase NFTs
        purchase_nft(&test_account, @0x1, 1);

        // Assertions to verify the purchase
        assert!(nft_sale.next_id == 1);
        assert!(nft_sale.total_sold == 1);
        assert!(nft_sale.total_supply == 100);
        assert!(nft_sale.max_nfts_per_tx == 5);
        assert!(nft_sale.price_per_nft == 1000);
        assert!(nft_sale.sale_start == 0);
        assert!(nft_sale.base_uri == b"test_uri");
        assert!(nft_sale.dev_wallet == @0x2);
        assert!(nft_sale.owner_wallet == @0x3);

        // Assertions that wallets received the payment
        assert!(coin::balance<AptosCoin>(@0x3) == 1000);
        assert!(coin::balance<AptosCoin>(@0x2) == 125000);
    }

    // Test modification of the owner wallet
    #[test]
    public fun test_modify_owner_wallet() {
        // Setup test environment and accounts
        let test_account = signer::create_signer(@0x1);

        // Initialize NFT sale
        init_nft_sale(&test_account, 100, 5, 1000, 0, b"test_uri", @0x2, @0x3);

        // Modify the owner wallet
        modify_owner_wallet(&test_account, @0x1, @0x4);

        // Assertions to verify the wallet modification    
        assert!(nft_sale.owner_wallet == @0x4);
    }
}
