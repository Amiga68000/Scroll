from PIL import Image

nom = "320x288x1p.bmp"


def valeur(adresse, longueur):
    v = 0
    n = 0
    for i in range(adresse, adresse + longueur):
        v = v + data[i] * 256 ** (n)
        n = n + 1
    return v

def writeBin(nomFichier, byte_arr):
    #byte_arr = [120, 3, 255, 0, 100]
    f = open(nomFichier, 'w+b')
    binary_format = bytearray(byte_arr)
    f.write(binary_format)
    f.close()
    return





print(nom)
f = open(nom, "rb")
data=f.read()
f.close()



#type du fichier bmp
bfType= chr(data[0])+chr(data[1])
print ("bfType = ",bfType)

#Taille du bitmap
bfSize = valeur(2, 4)
print("Taille fichier = ",bfSize," octets")

#Taille du bitmaps
biSize = valeur(int("0E",16),4)
n = 0
print("Taille entete = ",biSize," octets")

biWidth = valeur(int("12",16),4)
print("largeur = ",biWidth," pixels")

biHeight = valeur(int("16",16),4)
print("hauteur = ",biHeight," pixels")

biPlanes = valeur(int("1A",16),2)
print("nb de plans = ",biPlanes," plan")

biBitCount = valeur(int("1C",16),2)
print("nb bit count = ",biBitCount," bit/pixel")

biCompression = valeur(int("1E",16),4)
print("compression = ",biCompression," 0=pas de compression, 1=compressé à 8 bits par pixel, 2= 4 bits par pixel")

biSizeImage = valeur(int("22",16),4)
print("taille image = ",biSizeImage," octets")

biClrUsed = valeur(int("2E",16),4)
print("nb couleurs dans l'image = ",biClrUsed," 0=maximum possible. Si une palette est utilisée, ce nombre indique le nombre de couleurs de la palette")

taillePalette = biClrUsed * 4
adressImage = int("36",16) + taillePalette




i = Image.open(nom)
#Image.show(i)

(largeur, hauteur) = i.size
n = 7
v = 0

arr =[]
for y in range(hauteur):
    for x in range(largeur):
        c = i.getpixel((x, y))
        if c != 0:
            v = v + 2 ** n
        n = n - 1
        if n == -1:
            #print(format(v, "08b"))
            arr.append(v)
            n = 7
            v = 0



nomDest = nom + ".bin"
writeBin(nomDest,arr)




        #(rouge, vert, bleu) = i.getpixel(x, y)
        #print(rouge, vert, bleu)

#octet = format(15, "02x")  # 15--> 0f
#format(15,"04x")           # 15 --> 000f
#(int("ff",16))             # ff --> 255