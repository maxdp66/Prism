use adblock::content_blocking::CbRule;
use adblock::lists::{ParseOptions, RuleTypes};
use clap::{Parser, ValueEnum};
use log::{error, info, warn};
use serde_json::to_string_pretty;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, help = "Input filter list file(s)")]
    input: Vec<PathBuf>,

    #[arg(short, long, help = "Output JSON file")]
    output: Option<PathBuf>,

    #[arg(
        short,
        long,
        help = "Filter list format",
        default_value = "standard"
    )]
    format: FilterFormatArg,

    #[arg(
        short,
        long,
        help = "Include cosmetic (CSS hide) rules",
        default_value = "true"
    )]
    include_cosmetic: bool,

    #[arg(
        short,
        long,
        help = "Maximum number of rules to include (0 = unlimited)",
        default_value = "0"
    )]
    max_rules: usize,

    #[arg(short, long, help = "Download default filter lists")]
    download_defaults: bool,

    #[arg(
        short,
        long,
        help = "Silent mode (only errors)",
        default_value = "false"
    )]
    silent: bool,
}

#[derive(Debug, Clone, ValueEnum)]
enum FilterFormatArg {
    Standard,
    Hosts,
}

impl From<FilterFormatArg> for adblock::lists::FilterFormat {
    fn from(arg: FilterFormatArg) -> Self {
        match arg {
            FilterFormatArg::Standard => adblock::lists::FilterFormat::Standard,
            FilterFormatArg::Hosts => adblock::lists::FilterFormat::Hosts,
        }
    }
}

const DEFAULT_FILTER_LISTS: &[(&str, &str)] = &[
    (
        "EasyList",
        "https://easylist.to/easylist/easylist.txt",
    ),
    (
        "EasyPrivacy",
        "https://easylist.to/easylist/easyprivacy.txt",
    ),
    (
        "Fanboy's Annoyances",
        "https://easylist.to/easylist/fanboy-annoyance.txt",
    ),
];

fn download_filter_lists() -> Result<Vec<(String, String)>, Box<dyn std::error::Error>> {
    info!("Downloading default filter lists...");
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(60))
        .build()?;

    let mut results = Vec::new();

    for (name, url) in DEFAULT_FILTER_LISTS {
        info!("Downloading {} from {}", name, url);
        match client.get(*url).send() {
            Ok(response) => match response.text() {
                Ok(text) => {
                    info!("Downloaded {} ({} bytes)", name, text.len());
                    results.push((name.to_string(), text));
                }
                Err(e) => {
                    error!("Failed to read {}: {}", name, e);
                }
            },
            Err(e) => {
                error!("Failed to download {}: {}", name, e);
            }
        }
    }

    if results.is_empty() {
        return Err("Failed to download any filter lists".into());
    }

    Ok(results)
}

fn parse_filter_lists(
    lists: Vec<(String, String)>,
    format: adblock::lists::FilterFormat,
    include_cosmetic: bool,
    max_rules: usize,
) -> Vec<CbRule> {
    let debug_mode = true;
    let mut filter_set = adblock::lists::FilterSet::new(debug_mode);

    let rule_types = if include_cosmetic {
        RuleTypes::All
    } else {
        RuleTypes::NetworkOnly
    };

    let parse_options = ParseOptions {
        format,
        rule_types,
        ..Default::default()
    };

    for (name, content) in lists {
        info!("Parsing {} filter list...", name);
        filter_set.add_filter_list(&content, parse_options);
        info!("Added filters from {}", name);
    }

    info!("Converting filters to content blocking rules...");

    let result = filter_set.into_content_blocking();

    let (mut cb_rules, filters_used) = match result {
        Ok(data) => data,
        Err(()) => {
            error!("Failed to convert to content blocking rules - FilterSet was not in debug mode");
            return Vec::new();
        }
    };

    info!(
        "Conversion complete: {} content blocking rules from {} original filters",
        cb_rules.len(),
        filters_used.len()
    );

    // Apply rule limits
    if max_rules > 0 && cb_rules.len() > max_rules {
        info!(
            "Limiting from {} to {} rules",
            cb_rules.len(),
            max_rules
        );
        cb_rules.truncate(max_rules);
    }

    cb_rules
}

fn write_json_output(rules: &[CbRule], output: &PathBuf) -> Result<(), Box<dyn std::error::Error>> {
    let json = to_string_pretty(rules)?;
    fs::write(output, json)?;
    info!("Wrote {} rules to {:?}", rules.len(), output);
    Ok(())
}

fn main() -> ExitCode {
    let args = Args::parse();

    if !args.silent {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
            .format_timestamp_millis()
            .init();
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("error"))
            .format_timestamp_millis()
            .init();
    }

    info!("Adblock Content Blocker Generator");
    info!("==================================");

    let filter_lists: Vec<(String, String)>;

    if args.download_defaults {
        match download_filter_lists() {
            Ok(lists) => filter_lists = lists,
            Err(e) => {
                error!("Failed to download filter lists: {}", e);
                return ExitCode::FAILURE;
            }
        }
    } else if !args.input.is_empty() {
        let mut temp_lists = Vec::new();
        for path in &args.input {
            info!("Reading input from {:?}", path);
            match fs::read_to_string(path) {
                Ok(content) => {
                    let name = path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("unknown")
                        .to_string();
                    temp_lists.push((name, content));
                }
                Err(e) => {
                    error!("Failed to read {:?}: {}", path, e);
                    return ExitCode::FAILURE;
                }
            }
        }
        filter_lists = temp_lists;
    } else {
        error!("No input files specified. Use --input or --download-defaults");
        return ExitCode::FAILURE;
    }

    if filter_lists.is_empty() {
        error!("No filter lists available to process");
        return ExitCode::FAILURE;
    }

    let format: adblock::lists::FilterFormat = args.format.into();
    let rules = parse_filter_lists(
        filter_lists,
        format,
        args.include_cosmetic,
        args.max_rules,
    );

    if rules.is_empty() {
        error!("No content blocking rules were generated");
        return ExitCode::FAILURE;
    }

    if let Some(output_path) = args.output {
        if let Err(e) = write_json_output(&rules, &output_path) {
            error!("Failed to write output: {}", e);
            return ExitCode::FAILURE;
        }
    } else {
        let json = to_string_pretty(&rules).expect("Failed to serialize rules");
        println!("{}", json);
    }

    info!("Done! Generated {} content blocking rules", rules.len());
    ExitCode::SUCCESS
}