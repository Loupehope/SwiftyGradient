# Find source dir
dir="$( cd "$( dirname "${bash_source[0]}" )" && pwd )" 

cd "$dir"

# Lint
readonly linter="scripts/swiftlint/swiftlint"
readonly sources="Sources/SwiftyGradient"
readonly example="Example"
readonly config="scripts/swiftlint/.swiftlint.yml"

${linter} --fix --path ${sources} --path ${example} --config ${config}