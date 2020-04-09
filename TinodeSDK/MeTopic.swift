//
//  MeTopic.swift
//  TinodeSDK
//
//  Copyright © 2020 Tinode. All rights reserved.
//

import Foundation


open class MeTopic<DP: Codable & Mergeable>: Topic<DP, PrivateType, DP, PrivateType> {
    public init(tinode: Tinode?, l: MeTopic<DP>.Listener?) {
        super.init(tinode: tinode, name: Tinode.kTopicMe, l: l)
    }
    public init(tinode: Tinode?, desc: Description<DP, PrivateType>) {
        super.init(tinode: tinode, name: Tinode.kTopicMe, desc: desc)
    }

    override public var subsUpdated: Date? {
        get { return tinode?.topicsUpdated }
    }

    override func loadSubs() -> Int {
        // Don't attempt to load subscriptions: 'me' subscriptions are stored as topics.
        return 0
    }

    override public func topicLeft(unsub: Bool?, code: Int?, reason: String?) {
        super.topicLeft(unsub: unsub, code: code, reason: reason)
        if let topics = tinode?.getTopics() {
            for t in topics {
                t.online = false
            }
        }
    }

    override public func updateMode(update: String) -> PromisedReply<ServerMessage>? {
        var acs = accessMode
        if acs == nil {
           acs = Acs()
        }

        let mode = AcsHelper(ah: acs!.want)
        if mode.update(from: update) {
            return setSubscription(sub: MetaSetSub(user: nil, mode: mode.description))
        }

        // The state is unchanged, return resolved promise.
        return PromisedReply<ServerMessage>(value: ServerMessage())
    }

    override internal func update(acsMap: [String:String]?, sub: MetaSetSub) {
        var newAcs: Acs
        if let acsMap = acsMap {
            newAcs = Acs(from: acsMap)
        } else {
            newAcs = Acs()
            newAcs.want = AcsHelper(str: sub.mode)
        }

        var changed = false
        var acs = accessMode
        if acs == nil {
            acs = newAcs
            changed = true
        } else {
            changed = acs!.merge(from: newAcs)
        }

        if changed {
            accessMode = acs
            self.store?.topicUpdate(topic: self)
        }
    }

    override public func routePres(pres: MsgServerPres) {
        let what = MsgServerPres.parseWhat(what: pres.what)
        if what == .kTerm {
            // The 'me' topic itself is detached. Mark as unsubscribed.
            super.routePres(pres: pres)
            return
        }

        if what == .kUpd && Tinode.kTopicMe == pres.src {
            // Me's desc was updated, fetch the updated version.
            getMeta(query: getMetaGetBuilder().withDesc().build())
            return
        }

        // "what":"tags" has src == nil
        if let topic = pres.src != nil ? tinode!.getTopic(topicName: pres.src!) : nil {
            switch what {
            case .kOn: // topic came online
                topic.online = true
            case .kOff: // topic went offline
                topic.online = false
                topic.lastSeen = LastSeen(when: Date(), ua: nil)
            case .kMsg: // new message received
                topic.seq = pres.seq
                if pres.act == nil || tinode!.isMe(uid: pres.act!) {
                    assignRead(to: topic, read: pres.seq)
                }
                topic.touched = Date()
            case .kUpd: // pub/priv updated
                getMeta(query: getMetaGetBuilder().withSub(user: pres.src).build())
            case .kAcs: // access mode changed
                if topic.updateAccessMode(ac: pres.dacs) {
                    self.store?.topicUpdate(topic: topic)
                }
            case .kUa: // user agent changed
                topic.lastSeen = LastSeen(when: Date(), ua: pres.ua)
            case .kRecv: // user's other session marked some messages as received
                assignRecv(to: topic, recv: pres.seq)
            case .kRead: // user's other session marked some messages as read
                assignRead(to: topic, read: pres.seq)
            case .kGone:
                // If topic is unknown (==nil), then we don't care to unregister it.
                topic.persist(false)
                tinode!.stopTrackingTopic(topicName: pres.src!)
            case .kDel: // messages deleted
                // Explicitly ignored: 'me' topic has no messages.
                break
            default:
                Tinode.log.error("ME.pres message - unknown what: %@", String(describing: pres.what))
            }
        } else {
            // New topic
            switch what {
            case .kAcs:
                let acs = Acs()
                acs.update(from: pres.dacs)
                if acs.isModeDefined {
                    getMeta(query: getMetaGetBuilder().withSub(user: pres.src).build())
                } else {
                    Tinode.log.error("ME.acs - unexpected access mode: %@", String(describing: pres.dacs))
                }
            case .kTags:
                // Account tags updated
                getMeta(query: getMetaGetBuilder().withTags().build())
            default:
                Tinode.log.error("ME.pres - topic not found: what = %@, src = %@",
                                 String(describing: pres.what), String(describing: pres.src))
            }
        }

        if (what == MsgServerPres.What.kGone) {
            listener?.onSubsUpdated()
        }
        listener?.onPres(pres: pres)
    }

    fileprivate func assignRecv(to topic: TopicProto, recv seq: Int?) {
        if (topic.recv ?? -1) < (seq ?? -1) {
            topic.recv = seq
            self.store?.setRecv(topic: topic, recv: seq!)
        }
    }

    fileprivate func assignRead(to topic: TopicProto, read seq: Int?) {
        if (topic.read ?? -1) < (seq ?? -1) {
            topic.read = seq
            self.store?.setRead(topic: topic, read: topic.read!)
            assignRecv(to: topic, recv: topic.read)
        }
    }

    override internal func routeMetaSub(meta: MsgServerMeta) {
        if let metaSubs = meta.sub as? Array<Subscription<DP, PrivateType>> {
            for sub in metaSubs {
                if let topic = tinode!.getTopic(topicName: sub.topic!) {
                    if sub.deleted != nil {
                        topic.persist(false)
                        tinode!.stopTrackingTopic(topicName: sub.topic!)
                    } else {
                        if let t = topic as? DefaultTopic {
                            t.update(sub: sub as! Subscription<VCard, PrivateType>)
                        } else if let t = topic as? DefaultMeTopic {
                            t.update(sub: sub as! Subscription<VCard, PrivateType>)
                        } /*else if let t = topic as? DefaultFndTopic {
                            t.update(sub: sub)
                        } */
                        else {
                            Tinode.log.fault("ME.routeMetaSub - failed to update topic %@", String(describing: topic))
                            assert(false)
                        }
                    }
                } else if sub.deleted == nil {
                    let topic = tinode!.newTopic(sub: sub)
                    topic.persist(true)
                }
                listener?.onMetaSub(sub: sub)
            }
        }
        listener?.onSubsUpdated()
    }
}
