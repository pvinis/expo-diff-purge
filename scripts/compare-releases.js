#!/usr/bin/env node

import { gte, coerce } from "semver"

const left = coerce(process.argv[2])
const right = coerce(process.argv[3])

if (gte(left, right)) {
	process.exit(0)
}
process.exit(1)
