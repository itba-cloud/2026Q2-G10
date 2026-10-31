locals {
  account_id = data.aws_caller_identity.this.account_id

  # Sufijo de cuenta para los nombres que tienen que ser unicos en todo AWS
  suffix = local.account_id

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }

  # Nombres de los buckets, unicos globalmente
  bucket_front = format("%s-frontend-%s", var.project, local.suffix)
  bucket_media = format("%s-media-%s", var.project, local.suffix)

  # Catalogos de seed, un archivo JSON por tipo cargado como items
  # { "CATEGORIA#0001" = {...}, "ZONA#0001" = {...}, ... }
  seed_items = merge([
    for tipo in ["categoria", "zona", "urgencia"] : {
      for item in jsondecode(file("${path.module}/seed/${tipo}.json")) :
      "${upper(tipo)}#${format("%04d", item.id)}" => merge(item, { tipo = tipo })
    }
  ]...)

  # Momento base del seed de solicitudes. Se evalua una vez por apply y queda
  # fijo en cada item por el ignore_changes, asi las fechas no cambian despues.
  seed_now = timestamp()

  # Solicitudes de demo, recuperadas del seed que teniamos en RDS. Un objeto por
  # solicitud con su historial de seguimiento; las fechas son relativas a la
  # creacion (en horas) y cliente/profesional/actor referencian la clave de
  # demo_users (el sub de Cognito se resuelve recien en database.tf).
  solicitudes_seed = jsondecode(file("${path.module}/seed/solicitudes.json"))

  # id de solicitud -> objeto, con la fecha de creacion ya calculada
  solicitudes_by_id = {
    for s in local.solicitudes_seed :
    s.id => merge(s, {
      fecha_creacion = timeadd(local.seed_now, "-${s.creada_hace_horas}h")
    })
  }

  # Pasos de seguimiento aplanados. Clave "<id>#<nnnn>" para el for_each; el SK
  # se arma con el indice del paso para que ordene cronologico dentro de la SOL.
  seguimientos_seed = merge([
    for s in local.solicitudes_seed : {
      for idx, seg in s.seguimiento :
      "${s.id}#${format("%04d", idx + 1)}" => {
        id_solicitud = s.id
        sk           = "SEG#${format("%04d", idx + 1)}"
        estado       = seg.estado
        actor        = seg.actor
        profesional  = seg.profesional
        motivo       = seg.motivo
        fecha_desde  = timeadd(timeadd(local.seed_now, "-${s.creada_hace_horas}h"), "${seg.offset_horas}h")
      }
    }
  ]...)

  front_origin = var.front_origin != "" ? var.front_origin : "http://${local.bucket_front}.s3-website-${var.region}.amazonaws.com"

  # Content-Type por extension para los archivos del front subidos a S3
  content_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    svg  = "image/svg+xml"
    png  = "image/png"
    jpg  = "image/jpeg"
    ico  = "image/x-icon"
    map  = "application/json"
    txt  = "text/plain"
  }

  # Prefijo del dominio de la Hosted UI, unico globalmente
  cognito_domain_prefix = "${var.project}-${local.suffix}"

  # Lambdas de API que ya existen, cada una con sus rutas. Agregar un dominio es
  # sumar una entrada aca y su carpeta en back/functions/
  api_functions = {
    catalogos = {
      routes = ["GET /api/categorias", "GET /api/zonas", "GET /api/urgencias"]
      public = true
    }
    usuarios = {
      routes = ["GET /api/auth/me", "POST /api/auth/registro"]
      public = false
    }
    solicitudes = {
      routes = [
        "GET /api/solicitudes",
        "POST /api/solicitudes",
        "GET /api/trabajos",
        "GET /api/solicitudes/{id}",
        "GET /api/solicitudes/{id}/seguimiento",
      ]
      public = false
    }
    fotos = {
      routes = [
        "POST /api/solicitudes/{id}/fotos",
        "GET /api/solicitudes/{id}/fotos",
      ]
      public = false
    }
    flujo = {
      routes = [
        "POST /api/solicitudes/{id}/aceptar",
        "POST /api/solicitudes/{id}/iniciar",
        "POST /api/solicitudes/{id}/resolver",
        "POST /api/solicitudes/{id}/liberar",
        "POST /api/solicitudes/{id}/cancelar",
      ]
      public = false
    }
    calificaciones = {
      routes = [
        "POST /api/solicitudes/{id}/calificacion",
        "GET /api/solicitudes/{id}/calificacion",
      ]
      public = false
    }
  }

  # Aplana api_functions en un mapa ruta -> {fn, public} para el for_each de las rutas
  api_routes = merge([
    for fn, cfg in local.api_functions : {
      for ruta in cfg.routes : ruta => { fn = fn, public = cfg.public }
    }
  ]...)

  # Mock data, usuarios de demo. username (clave) -> datos del perfil.
  # Las categorias de los profesionales referencian los ids de seed/categoria.json.
  # descripcion queda "" en los clientes: solo la usan los profesionales (ver database.tf).
  demo_users = {
    # Clientes
    "juan.perez" = {
      email       = "juan.perez@example.com"
      nombre      = "Juan"
      apellido    = "Pérez"
      telefono    = "+54 11 5555-1001"
      rol         = "CLIENTE"
      categorias  = []
      descripcion = ""
    }
    "sofia.garcia" = {
      email       = "sofia.garcia@example.com"
      nombre      = "Sofía"
      apellido    = "García"
      telefono    = "+54 11 5555-1002"
      rol         = "CLIENTE"
      categorias  = []
      descripcion = ""
    }
    "martin.lopez" = {
      email       = "martin.lopez@example.com"
      nombre      = "Martín"
      apellido    = "López"
      telefono    = "+54 11 5555-1003"
      rol         = "CLIENTE"
      categorias  = []
      descripcion = ""
    }
    "valentina.romero" = {
      email       = "valentina.romero@example.com"
      nombre      = "Valentina"
      apellido    = "Romero"
      telefono    = "+54 11 5555-1004"
      rol         = "CLIENTE"
      categorias  = []
      descripcion = ""
    }
    "lucas.fernandez" = {
      email       = "lucas.fernandez@example.com"
      nombre      = "Lucas"
      apellido    = "Fernández"
      telefono    = "+54 11 5555-1005"
      rol         = "CLIENTE"
      categorias  = []
      descripcion = ""
    }

    # Profesionales
    "carlos.electricista" = {
      email       = "carlos.gomez@example.com"
      nombre      = "Carlos"
      apellido    = "Gómez"
      telefono    = "+54 11 5555-2001"
      rol         = "PROFESIONAL"
      categorias  = [2, 17, 30]
      descripcion = "Electricista matriculado. Instalaciones eléctricas, reparación de cortocircuitos, tableros, térmicas, disyuntores y luminarias."
    }
    "diego.plomero" = {
      email       = "diego.martinez@example.com"
      nombre      = "Diego"
      apellido    = "Martínez"
      telefono    = "+54 11 5555-2002"
      rol         = "PROFESIONAL"
      categorias  = [1, 25]
      descripcion = "Plomero con experiencia en pérdidas de agua, grifería, cañerías, destapaciones y reparación de sanitarios."
    }
    "mariano.gasista" = {
      email       = "mariano.rodriguez@example.com"
      nombre      = "Mariano"
      apellido    = "Rodríguez"
      telefono    = "+54 11 5555-2003"
      rol         = "PROFESIONAL"
      categorias  = [3, 4]
      descripcion = "Gasista especializado en instalación, mantenimiento y reparación de calefones, termotanques y cocinas."
    }
    "pablo.pintor" = {
      email       = "pablo.sanchez@example.com"
      nombre      = "Pablo"
      apellido    = "Sánchez"
      telefono    = "+54 11 5555-2004"
      rol         = "PROFESIONAL"
      categorias  = [7, 8, 10, 25]
      descripcion = "Pintor de interiores y exteriores. Preparación de paredes, pintura, enduido, impermeabilización y terminaciones."
    }
    "federico.tecnico" = {
      email       = "federico.torres@example.com"
      nombre      = "Federico"
      apellido    = "Torres"
      telefono    = "+54 11 5555-2005"
      rol         = "PROFESIONAL"
      categorias  = [4, 14, 15, 16]
      descripcion = "Técnico especializado en aire acondicionado, refrigeración y mantenimiento general de equipos domiciliarios."
    }
  }
}
