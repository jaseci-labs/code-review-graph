impl __getattr__(name: str) -> Any {
    target: any = _LAZY_EXPORTS.get(name);
    if target is not None {
        mod_path: any;
        attr: any;
        (mod_path, attr) = target as any;
        mod: any = importlib.import_module(mod_path, __name__);
        val: any = getattr(mod, attr);
        globals()[name] = val;
        return val;
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
