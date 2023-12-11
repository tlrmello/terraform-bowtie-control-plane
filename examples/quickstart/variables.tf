variable "control_plane_name" {
    default = "bowtie"
}

variable bootstrap_hosts {
  type = list(string)
  default = [
    "ohio-b-00.bowtie.rock.associates.example",
    "ohio-b-01.bowtie.rock.associates.example",
    "oregon-a-00.bowtie.rock.associates.example",
    "oregon-a-01.bowtie.rock.associates.example",
  ]
}

variable bowtie_admin_email {
    # Bowtie initial user settings that will pre-seed the Controller.
    default = "issac@issackelly.com"
}

variable bowtie_admin_password{
    default = "A Pretty Dec password is randomab4582a6ac34e6213edc"
}