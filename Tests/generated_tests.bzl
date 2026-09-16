# GENERATED FILE. DO NOT EDIT!

"""Generated test targets for SwiftLint rules."""

load(":test_macros.bzl", "generated_test_shard")

GENERATED_TEST_TARGETS = [
    "//Tests:GeneratedTests_01",
    "//Tests:GeneratedTests_02",
    "//Tests:GeneratedTests_03",
    "//Tests:GeneratedTests_04"
]

def generated_tests():
    """Creates all generated test targets for SwiftLint rules."""
    generated_test_shard("01")
    generated_test_shard("02")
    generated_test_shard("03")
    generated_test_shard("04")

    native.test_suite(
        name = "GeneratedTests",
        tests = GENERATED_TEST_TARGETS,
        visibility = ["//visibility:public"],
    )
