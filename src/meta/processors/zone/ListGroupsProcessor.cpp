/* Copyright (c) 2020 vesoft inc. All rights reserved.
 *
 * This source code is licensed under Apache 2.0 License.
 */

#include "meta/processors/zone/ListGroupsProcessor.h"

namespace nebula {
namespace meta {

void ListGroupsProcessor::process(const cpp2::ListGroupsReq&) {
  folly::SharedMutex::ReadHolder rHolder(LockUtils::groupLock());
  const auto& prefix = MetaKeyUtils::groupPrefix();
  auto iterRet = doPrefix(prefix);
  if (!nebula::ok(iterRet)) {
    auto retCode = nebula::error(iterRet);
    LOG(ERROR) << "List groups failed, error: " << apache::thrift::util::enumNameSafe(retCode);
    handleErrorCode(retCode);
    onFinished();
    return;
  }
  auto iter = nebula::value(iterRet).get();

  std::vector<cpp2::Group> groups;
  while (iter->valid()) {
    auto groupName = MetaKeyUtils::parseGroupName(iter->key());
    auto zoneNames = MetaKeyUtils::parseZoneNames(iter->val());
    cpp2::Group group;
    group.set_group_name(std::move(groupName));
    group.set_zone_names(std::move(zoneNames));
    groups.emplace_back(std::move(group));
    iter->next();
  }

  handleErrorCode(nebula::cpp2::ErrorCode::SUCCEEDED);
  resp_.set_groups(std::move(groups));
  onFinished();
}

}  // namespace meta
}  // namespace nebula
