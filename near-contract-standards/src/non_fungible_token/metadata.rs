use near_sdk::borsh::{self, BorshDeserialize, BorshSerialize};
use near_sdk::json_types::Base64VecU8;
use near_sdk::serde::{Deserialize, Serialize};

pub const NFT_METADATA_SPEC: &str = "nft-1.0.0";

#[derive(BorshDeserialize, BorshSerialize, Clone, Deserialize, Serialize)]
#[serde(crate = "near_sdk::serde")]
pub struct NonFungibleTokenMetadata {
    pub spec: String,
    pub name: String,
    pub symbol: String,
    pub icon: Option<String>,
    pub reference: Option<String>,
    pub reference_hash: Option<Base64VecU8>,
    pub decimals: u8,
}

pub trait NonFungibleTokenMetadataProvider {
    fn nft_metadata(&self) -> NonFungibleTokenMetadata;
}

impl NonFungibleTokenMetadata {
    pub fn assert_valid(&self) {
        assert_eq!(&self.spec, NFT_METADATA_SPEC);
        assert_eq!(self.reference.is_some(), self.reference_hash.is_some());
        if let Some(reference_hash) = &self.reference_hash {
            assert_eq!(reference_hash.0.len(), 32, "Hash has to be 32 bytes");
        }
    }
}
