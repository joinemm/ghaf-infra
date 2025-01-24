#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0

command="jenkinsPlugins2nix"
while IFS= read -r line; do
	command+=" -p $line"
done <"$1"

eval "$command"
