module YourAddress::NFTSale {
    use std::signer::{self, Signer};
    use aptos_framework::timestamp;
    use aptos_framework::coin::{self, Coin};
    use aptos_framework::nft::{self, NFT};

    // Structure representing the NFT sale
    struct NFTForSale has key {
        next_id: u64,
        total_sold: u64,
        total_supply: u64,
        max_nfts_per_tx: u64,
        price_per_nft: u64,
        sale_start: u64,
        sale_end: u64,
        base_uri: vector<u8>,
    }

    // Initialize the NFT sale
    public fun init_nft_sale(account: &signer, total_supply: u64, max_nfts_per_tx: u64, price_per_nft: u64, sale_start: u64, sale_end: u64, base_uri: vector<u8>) {
        let nft_sale_data = NFTForSale {
            next_id: 0,
            total_sold: 0,
            total_supply: total_supply,
            max_nfts_per_tx: max_nfts_per_tx,
            price_per_nft: price_per_nft,
            sale_start: sale_start,
            sale_end: sale_end,
            base_uri: base_uri,
        };
        move_to(account, nft_sale_data);
    }

    // Purchase NFTs
    public fun purchase_nft(account: &signer, owner: address, quantity: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);

        // Validate purchase conditions
        let now = timestamp::now_microseconds();
        assert!(now >= SALE_START && now <= SALE_END, 9999); // Invalid time
        assert!(quantity > 0 && quantity <= nft_sale.max_nfts_per_tx, 8888); // Invalid quantity
        assert!(nft_sale.total_sold + quantity <= nft_sale.total_supply, 7777); // Exceeds total supply

        // Check if the buyer has enough funds
        let total_price = nft_sale.price * quantity;
        let buyer_balance = coin::balance<Coin>(account);
        assert!(buyer_balance >= total_price, 6666); // Insufficient funds

        // Transfer funds and mint NFTs
        coin::transfer_from_sender<Coin>(owner, total_price);
        for _ in 0..quantity {
            let metadata_uri = BASE_URI + &b"/".to_vec() + &nft_sale.next_id.to_string().into_bytes();
            nft::mint(account, metadata_uri, owner); // Mint function in the NFT module
            nft_sale.next_id += 1;
        }

        // Update total sold
        nft_sale.total_sold += quantity;
    }

    // Function to view current NFT sale status
    public fun view_nft_sale_status(owner: address): (u64, u64, u64, u64, u64) acquires NFTForSale {
        let nft_sale = borrow_global<NFTForSale>(owner);
        (nft_sale.next_id, nft_sale.total_sold, nft_sale.total_supply, nft_sale.max_nfts_per_tx, nft_sale.price)
    }

    // Function to modify the price per NFT
    public fun modify_price_per_nft(account: &signer, owner: address, new_price: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, 5555); // Unauthorized
        nft_sale.price_per_nft = new_price;
    }

    // Function to modify the max NFTs per transaction
    public fun modify_max_nfts_per_tx(account: &signer, owner: address, new_max: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, 5555); // Unauthorized
        nft_sale.max_nfts_per_tx = new_max;
    }

    // Function to modify the total supply
    public fun modify_total_supply(account: &signer, owner: address, new_total_supply: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, 5555); // Unauthorized
        assert!(new_total_supply >= nft_sale.total_sold, 4444); // Invalid total supply
        nft_sale.total_supply = new_total_supply;
    }

    // Function to modify the sale start time
    public fun modify_sale_start(account: &signer, owner: address, new_start: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, 5555); // Unauthorized
        nft_sale.sale_start = new_start;
    }

    // Function to modify the sale end time
    public fun modify_sale_end(account: &signer, owner: address, new_end: u64) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, 5555); // Unauthorized
        nft_sale.sale_end = new_end;
    }

    // Function to modify the base URI
    public fun modify_base_uri(account: &signer, owner: address, new_base_uri: vector<u8>) acquires NFTForSale {
        let nft_sale = borrow_global_mut<NFTForSale>(owner);
        assert!(signer::address_of(account) == owner, 5555); // Unauthorized
        nft_sale.base_uri = new_base_uri;
    }
}
