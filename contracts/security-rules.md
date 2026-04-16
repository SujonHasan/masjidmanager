# Security Rules Notes

The initial rules use mosque-level membership documents:

```txt
mosques/{mosqueId}/users/{uid}
```

A user can access a mosque only if their membership document exists and is active. Admin-like roles can write operational records. Guest/member read expansion should be tightened per feature before public launch.
