// Library interface for fnox

pub mod auth_prompt;
pub mod commands;
pub mod config;
pub mod env;
pub mod error;
pub mod hook_env;
#[cfg(feature = "lease")]
pub mod http;
#[cfg(feature = "lease")]
pub mod lease;
#[cfg(feature = "lease")]
pub mod lease_backends;
#[cfg(feature = "mcp")]
pub mod mcp_server;
pub mod providers;
pub mod secret_resolver;
pub mod settings;
pub mod shell;
pub mod source_registry;
pub mod spanned;
pub mod suggest;
pub mod temp_file_secrets;
#[cfg(feature = "tui")]
pub mod tui;

// Re-export commonly used items
pub use error::{FnoxError, Result};
