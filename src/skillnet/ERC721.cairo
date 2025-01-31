#[starknet::contract]
pub mod erc721 {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use starknet::ContractAddress;
    use core::num::traits::zero::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::{access::ownable::OwnableComponent};

    use starknet::storage::{Map, StoragePointerWriteAccess, StorageMapWriteAccess};
    use contract::interfaces::IErc721::{IERC721, IERC721Dispatcher, IERC721DispatcherTrait};

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // *************************************************************************
    //                             STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        admin: ContractAddress,
        last_minted_id: u256,
        // user_token_id: Map<ContractAddress, u256>,
    }

    // *************************************************************************
    //                             EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.erc721.initializer("SPIDERS", "WEBS", "" // The pinata URL will be updated soon
        );
    }


    #[abi(embed_v0)]
    impl IERC721Impl of IERC721<ContractState> {
        // *************************************************************************
        //                            EXTERNAL
        // *************************************************************************

        fn mint_nft(ref self: ContractState, address: ContractAddress) -> u256 {
            assert(address.is_non_zero(), 'INVALID_ADDRESS');
            let token_id = self.last_minted_id.read() + 1;
            self.erc721.mint(address, token_id);
            // self.last_minted_id.write(token_id);
            token_id
        }
    }
}