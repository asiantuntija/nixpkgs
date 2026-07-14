{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  rustPlatform,
  cmake,
  dbus,
  libxcb,
  pkg-config,
  protobuf,
  openssl,
  cacert,
  writableTmpDirAsHomeHook,
  versionCheckHook,
  git,
  nix-update-script,
  llvmPackages,
  makeWrapper,
  librusty_v8 ? callPackage ./librusty_v8.nix {
    inherit (callPackage ./fetchers.nix { }) fetchLibrustyV8;
  },

  # Extension(s) Dependencies
  python3,
  bash,
  # X11
  xdotool,
  wmctrl,
  xclip,
  xwininfo,
  # Wayland
  wtype,
  wl-clipboard,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "goose-cli";
  version = "1.43.0";

  src = fetchFromGitHub {
    owner = "aaif-goose";
    repo = "goose";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lmeS+iOyZ262H9NykK3GFIEA7ipOnqnurRKPY8xbwKw=";
  };

  postPatch = ''
    # rustc overflows its query depth limit compiling the ACP test binaries
    # (deeply nested async closures in acp::server::dispatch). Upstream added
    # #![recursion_limit = "256"] only to acp_provider_test.rs; extend it to
    # the sibling test files.
    for f in crates/goose/tests/acp_*_test.rs; do
      grep -q recursion_limit "$f" || sed -i '1i #![recursion_limit = "256"]' "$f"
    done
  '';

  cargoHash = "sha256-OgYI8hVRUIY/Kl0PKJ+LZ98UCNrW7/p211EUtGOWwiI=";

  cargoBuildFlags = [
    "--bin"
    "goose"
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
    rustPlatform.bindgenHook
    makeWrapper
  ];

  buildInputs = [
    dbus
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ libxcb ];

  env = {
    LIBCLANG_PATH = "${lib.getLib llvmPackages.libclang}/lib";
    RUSTY_V8_ARCHIVE = librusty_v8;
  };

  postFixup = ''
    wrapProgram $out/bin/goose \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            bash
            python3
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            # X11
            xdotool
            wmctrl
            xclip
            xwininfo
            # Wayland
            wtype
            wl-clipboard
          ]
        )
      }
  '';

  nativeCheckInputs = [
    writableTmpDirAsHomeHook
    cacert
    git
  ];

  __darwinAllowLocalNetworking = true;

  checkFlags = [
    # need dbus-daemon for keychain access
    "--skip=config::base::tests::test_multiple_secrets"
    "--skip=config::base::tests::test_secret_management"
    "--skip=config::base::tests::test_concurrent_extension_writes"
    "--skip=config::signup_tetrate::tests::test_configure_tetrate"
    # Observer should be Some with both init project keys set
    "--skip=tracing::langfuse_layer::tests::test_create_langfuse_observer"
    "--skip=providers::gcpauth::tests::test_token_refresh_race_condition"
    # need API keys
    "--skip=providers::factory::tests::test_create_lead_worker_provider"
    "--skip=providers::factory::tests::test_create_regular_provider_without_lead_config"
    "--skip=providers::factory::tests::test_lead_model_env_vars_with_defaults"
    # need network access
    "--skip=test_concurrent_access"
    "--skip=test_model_not_in_openrouter"
    "--skip=test_pricing_cache_performance"
    "--skip=test_pricing_refresh"
    # integration tests that need network access
    "--skip=test_replayed_session::vec_uvx_mcp_server_fetch_vec_calltoolrequestparam_name_fetch_into_arguments_some_object_url_https_example_com_vec_expects"
    "--skip=test_replayed_session::vec_github_mcp_server_stdio_vec_calltoolrequestparam_name_get_file_contents_into_arguments_some_object_owner_block_repo_goose_path_readme_md_sha_ab62b863c1666232a67048b6c4e10007a2a5b83c_vec_github_personal_access_token_expects"
    "--skip=test_replayed_session::vec_npx_y_modelcontextprotocol_server_everything_vec_calltoolrequestparam_name_echo_into_arguments_some_object_message_hello_world_calltoolrequestparam_name_add_into_arguments_some_object_a_1_b_2_calltoolrequestparam_name_longrunningoperation_into_arguments_some_object_duration_1_steps_5_calltoolrequestparam_name_structuredcontent_into_arguments_some_object_location_11238_vec_expects"
    # global login-shell PATH cache (hooks::hook_path OnceLock) is poisoned by
    # parallel tests overriding GOOSE_SHELL; fails in the sandbox
    "--skip=hooks::tests::matcher_filters_by_tool_name"
    "--skip=plugins::discovery::tests::enabled_in_config_keeps_plugin_without_modifying_config"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    "--skip=context_mgmt::auto_compact::tests::test_auto_compact_respects_config"
    "--skip=scheduler::tests::test_scheduled_session_has_schedule_id"
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64) [
    # Broken on aarch64-linux: request capture races across session_id_propagation_test cases
    "--skip=test_session_id_matches_across_calls"
    "--skip=test_session_id_propagation_to_llm"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "--skip=logging::tests::test_log_file_name_no_session"
    "--skip=recipes::extract_from_cli::tests::test_extract_recipe_info_from_cli_basic"
    "--skip=recipes::extract_from_cli::tests::test_extract_recipe_info_from_cli_with_additional_sub_recipes"
    "--skip=recipes::recipe::tests::load_recipe::test_load_recipe_success"
    "--skip=test_session_id_matches_across_calls"
    "--skip=test_session_id_propagation_to_llm"
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Open-source, extensible AI agent that goes beyond code suggestions - install, execute, edit, and test with any LLM";
    homepage = "https://github.com/aaif-goose/goose";
    mainProgram = "goose";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      cloudripper
      thardin
      brittonr
      miniharinn
      caniko
    ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
