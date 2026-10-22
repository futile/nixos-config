// Node loader entry for testing the vendored bash-async extension outside Pi.
import { register } from "node:module";

register("./loader.mjs", import.meta.url);
