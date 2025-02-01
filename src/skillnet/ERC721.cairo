#[starknet::contract]
mod ERC721Contract {
    use core::starknet::{
        ContractAddress, get_caller_address, contract_address_to_felt252,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess},
    };
    use traits::{Into, TryInto};
    use option::OptionTrait;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        token_ids: u256,
        owners: Map<u256, ContractAddress>,
        balances: Map<ContractAddress, u256>,
        token_approvals: Map<u256, ContractAddress>,
        operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        token_uri: Map<u256, felt252>,
    }

    #[event]
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Approval: Approval,
        Transfer: Transfer,
        ApprovalForAll: ApprovalForAll,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Approval {
        owner: ContractAddress,
        to: ContractAddress,
        token_id: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    struct ApprovalForAll {
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool,
    }

    mod Errors {
        pub const APPROVE_FROM_ZERO: felt252 = 'ERC721: approve from 0';
        pub const APPROVE_TO_ZERO: felt252 = 'ERC721: approve to 0';
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC721: transfer from 0';
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC721: transfer to 0';
        pub const BURN_FROM_ZERO: felt252 = 'ERC721: burn from 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC721: mint to 0';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _name: felt252, _symbol: felt252) {
        self.name.write(_name);
        self.symbol.write(_symbol);
    }

    #[external(v0)]
    #[generate_trait]
    impl IERC721Impl of IERC721Trait {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_token_uri(self: @ContractState, token_id: u256) -> felt252 {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self.token_uri.read(token_id)
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(account.is_non_zero(), 'ERC721: address zero');
            self.balances.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.owners.read(token_id);
            assert(owner.is_non_zero(), 'ERC721: invalid token ID');
            owner
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self.token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.operator_approvals.read((owner, operator))
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self.owner_of(token_id);
            assert(to != owner, 'Approval to current owner');
            assert(
                get_caller_address() == owner
                    || self.is_approved_for_all(owner, get_caller_address()),
                'Not token owner',
            );
            self.token_approvals.write(token_id, to);
            self.emit(Approval { owner: self.owner_of(token_id), to: to, token_id: token_id });
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            let owner = get_caller_address();
            assert(owner != operator, 'ERC721: approve to caller');
            self.operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner: owner, operator: operator, approved: approved });
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id),
                'neither owner nor approved',
            );
            self._transfer(from, to, token_id);
        }

        fn set_token_uri(ref self: ContractState, token_id: u256, token_uri: felt252) {
            let owner = get_caller_address();
            assert(self.owner_of(token_id) == owner, 'ERC721: token does not belong to user');
            self._set_token_uri(token_id, token_uri);
        }

        fn mint(ref self: ContractState, recipient: ContractAddress) -> u256 {
            let token_id = self.token_ids.read() + 1;
            self._mint(recipient, token_id);
            self.token_ids.write(token_id);
            token_id
        }
    }

    #[generate_trait]
    impl ERC721HelperImpl of ERC721HelperTrait {
        fn _exists(self: @ContractState, token_id: u256) -> bool {
            self.owner_of(token_id).is_non_zero()
        }

        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256,
        ) -> bool {
            let owner = self.owners.read(token_id);
            spender == owner
                || self.is_approved_for_all(owner, spender)
                || self.get_approved(token_id) == spender
        }

        fn _set_token_uri(ref self: ContractState, token_id: u256, token_uri: felt252) {
            assert(self._exists(token_id), 'ERC721: invalid token ID');
            self.token_uri.write(token_id, token_uri)
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            assert(from == self.owner_of(token_id), 'ERC721: Caller is not owner');
            assert(to.is_non_zero(), 'ERC721: transfer to 0 address');

            self.token_approvals.write(token_id, Zeroable::zero());

            self.balances.write(from, self.balances.read(from) - 1.into());
            self.balances.write(to, self.balances.read(to) + 1.into());

            self.owners.write(token_id, to);

            self.emit(Transfer { from: from, to: to, token_id: token_id });
        }

        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(to.is_non_zero(), 'TO_IS_ZERO_ADDRESS');

            assert(!self.owner_of(token_id).is_non_zero(), 'ERC721: Token already minted');

            let receiver_balance = self.balances.read(to);
            self.balances.write(to, receiver_balance + 1.into());

            self.owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to: to, token_id: token_id });
        }

        fn _burn(ref self: ContractState, token_id: u256) {
            let owner = self.owner_of(token_id);

            self.token_approvals.write(token_id, Zeroable::zero());

            let owner_balance = self.balances.read(owner);
            self.balances.write(owner, owner_balance - 1.into());

            self.owners.write(token_id, Zeroable::zero());
            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id: token_id });
        }
    }
}
