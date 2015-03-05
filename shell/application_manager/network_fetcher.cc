// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "shell/application_manager/network_fetcher.h"

#include "base/bind.h"
#include "base/files/file.h"
#include "base/files/file_path.h"
#include "base/files/file_util.h"
#include "base/message_loop/message_loop.h"
#include "base/process/process.h"
#include "base/stl_util.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/string_util.h"
#include "base/strings/stringprintf.h"
#include "crypto/secure_hash.h"
#include "crypto/sha2.h"
#include "mojo/common/common_type_converters.h"
#include "mojo/common/data_pipe_utils.h"
#include "mojo/services/network/public/interfaces/network_service.mojom.h"
#include "shell/application_manager/data_pipe_peek.h"

namespace mojo {
namespace shell {

NetworkFetcher::NetworkFetcher(bool disable_cache,
                               const GURL& url,
                               NetworkService* network_service,
                               const FetchCallback& loader_callback)
    : Fetcher(loader_callback),
      disable_cache_(false),
      url_(url),
      weak_ptr_factory_(this) {
  StartNetworkRequest(url, network_service);
}

NetworkFetcher::~NetworkFetcher() {
}

const GURL& NetworkFetcher::GetURL() const {
  return url_;
}

GURL NetworkFetcher::GetRedirectURL() const {
  if (!response_)
    return GURL::EmptyGURL();

  if (response_->redirect_url.is_null())
    return GURL::EmptyGURL();

  return GURL(response_->redirect_url);
}

URLResponsePtr NetworkFetcher::AsURLResponse(base::TaskRunner* task_runner,
                                             uint32_t skip) {
  if (skip != 0) {
    MojoResult result = ReadDataRaw(
        response_->body.get(), nullptr, &skip,
        MOJO_READ_DATA_FLAG_ALL_OR_NONE | MOJO_READ_DATA_FLAG_DISCARD);
    DCHECK_EQ(result, MOJO_RESULT_OK);
  }
  return response_.Pass();
}

void NetworkFetcher::RecordCacheToURLMapping(const base::FilePath& path,
                                             const GURL& url) {
  // This is used to extract symbols on android.
  // TODO(eseidel): All users of this log should move to using the map file.
  base::FilePath temp_dir;
  base::GetTempDir(&temp_dir);
  base::ProcessId pid = base::Process::Current().Pid();
  std::string map_name = base::StringPrintf("mojo_shell.%d.maps", pid);
  base::FilePath map_path = temp_dir.Append(map_name);

  // TODO(eseidel): Paths or URLs with spaces will need quoting.
  std::string map_entry =
      base::StringPrintf("%s %s\n", path.value().c_str(), url.spec().c_str());
  // TODO(eseidel): AppendToFile is missing O_CREAT, crbug.com/450696
  if (!PathExists(map_path))
    base::WriteFile(map_path, map_entry.data(), map_entry.length());
  else
    base::AppendToFile(map_path, map_entry.data(), map_entry.length());
}

// AppIds should be be both predictable and unique, but any hash would work.
// Currently we use sha256 from crypto/secure_hash.h
bool NetworkFetcher::ComputeAppId(const base::FilePath& path,
                                  std::string* digest_string) {
  scoped_ptr<crypto::SecureHash> ctx(
      crypto::SecureHash::Create(crypto::SecureHash::SHA256));
  base::File file(path, base::File::FLAG_OPEN | base::File::FLAG_READ);
  if (!file.IsValid()) {
    LOG(ERROR) << "Failed to open " << path.value() << " for computing AppId";
    return false;
  }
  char buf[1024];
  while (file.IsValid()) {
    int bytes_read = file.ReadAtCurrentPos(buf, sizeof(buf));
    if (bytes_read == 0)
      break;
    ctx->Update(buf, bytes_read);
  }
  if (!file.IsValid()) {
    LOG(ERROR) << "Error reading " << path.value();
    return false;
  }
  // The output is really a vector of unit8, we're cheating by using a string.
  std::string output(crypto::kSHA256Length, 0);
  ctx->Finish(string_as_array(&output), output.size());
  output = base::HexEncode(output.c_str(), output.size());
  // Using lowercase for compatiblity with sha256sum output.
  *digest_string = base::StringToLowerASCII(output);
  return true;
}

bool NetworkFetcher::RenameToAppId(const base::FilePath& old_path,
                                   base::FilePath* new_path) {
  std::string app_id;
  if (!ComputeAppId(old_path, &app_id))
    return false;

  base::FilePath temp_dir;
  base::GetTempDir(&temp_dir);
  std::string unique_name = base::StringPrintf("%s.mojo", app_id.c_str());
  *new_path = temp_dir.Append(unique_name);
  return base::Move(old_path, *new_path);
}

void NetworkFetcher::CopyCompleted(
    base::Callback<void(const base::FilePath&, bool)> callback,
    bool success) {
  // The copy completed, now move to $TMP/$APP_ID.mojo before the dlopen.
  if (success) {
    success = false;
    base::FilePath new_path;
    if (RenameToAppId(path_, &new_path)) {
      if (base::PathExists(new_path)) {
        path_ = new_path;
        success = true;
        RecordCacheToURLMapping(path_, url_);
      }
    }
  }

  base::MessageLoop::current()->PostTask(FROM_HERE,
                                         base::Bind(callback, path_, success));
}

void NetworkFetcher::AsPath(
    base::TaskRunner* task_runner,
    base::Callback<void(const base::FilePath&, bool)> callback) {
  if (!path_.empty() || !response_) {
    base::MessageLoop::current()->PostTask(
        FROM_HERE, base::Bind(callback, path_, base::PathExists(path_)));
    return;
  }

  base::CreateTemporaryFile(&path_);
  common::CopyToFile(response_->body.Pass(), path_, task_runner,
                     base::Bind(&NetworkFetcher::CopyCompleted,
                                weak_ptr_factory_.GetWeakPtr(), callback));
}

std::string NetworkFetcher::MimeType() {
  return response_->mime_type;
}

bool NetworkFetcher::HasMojoMagic() {
  std::string magic;
  return BlockingPeekNBytes(response_->body.get(), &magic, strlen(kMojoMagic),
                            kPeekTimeout) &&
         magic == kMojoMagic;
}

bool NetworkFetcher::PeekFirstLine(std::string* line) {
  return BlockingPeekLine(response_->body.get(), line, kMaxShebangLength,
                          kPeekTimeout);
}

void NetworkFetcher::StartNetworkRequest(const GURL& url,
                                         NetworkService* network_service) {
  URLRequestPtr request(URLRequest::New());
  request->url = String::From(url);
  request->auto_follow_redirects = false;
  request->bypass_cache = disable_cache_;

  network_service->CreateURLLoader(GetProxy(&url_loader_));
  url_loader_->Start(request.Pass(),
                     base::Bind(&NetworkFetcher::OnLoadComplete,
                                weak_ptr_factory_.GetWeakPtr()));
}

void NetworkFetcher::OnLoadComplete(URLResponsePtr response) {
  if (response->error) {
    LOG(ERROR) << "Error (" << response->error->code << ": "
               << response->error->description << ") while fetching "
               << response->url;
    loader_callback_.Run(make_scoped_ptr<Fetcher>(NULL));
    return;
  }

  if (response->status_code >= 400 && response->status_code < 600) {
    LOG(ERROR) << "Error (" << response->status_code << ": "
               << response->status_line << "): "
               << "while fetching " << response->url;
    loader_callback_.Run(make_scoped_ptr<Fetcher>(NULL));
    return;
  }

  response_ = response.Pass();
  loader_callback_.Run(make_scoped_ptr(this));
}

}  // namespace shell
}  // namespace mojo