# El Barto App

Aplicacion Flutter para carta digital, delivery y panel administrador del
restaurante El Barto.

## Panel administrador

En la version web publicada en GitHub Pages, el login del administrador abre
directamente en:

```text
https://N-stack22.github.io/el-barto-app/
```

La ruta interna del panel tambien queda disponible en:

```text
https://N-stack22.github.io/el-barto-app/#/admin
```

El acceso usa Firebase Authentication con correo y contrasena. Para permitir
que un usuario entre al panel, crea el usuario en Firebase Auth y en Firestore
agrega o actualiza el documento:

```text
usuarios/{uid}
```

Con alguno de estos campos:

```json
{
  "rol": "admin"
}
```

o:

```json
{
  "roles": ["admin"]
}
```

Desde el panel se pueden ver, buscar, filtrar, crear, editar y eliminar los
productos de la coleccion `productos_restaurante`. Tambien se puede activar o
desactivar `disponible` y `destacado`.

## Publicacion en GitHub Pages

El repositorio incluye el workflow:

```text
.github/workflows/pages.yml
```

Cada push a `main` compila Flutter Web con:

```text
flutter build web --release --base-href /el-barto-app/
```

Luego publica `build/web` en GitHub Pages. En la configuracion del repositorio
de GitHub, activa Pages usando `GitHub Actions` como fuente.
